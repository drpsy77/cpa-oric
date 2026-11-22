#!/usr/bin/env python3
"""Génère l'aide de CP/A, en français et en anglais, à partir d'une liste de
pages par langue (PAGES, PAGES_EN : mêmes pages, même nombre de lignes) :
  files/readme.txt, files/en/readme.txt
                     README.TXT de la disquette : notation et renvoi à HELP
  progs/msg/fr/helptab.msg, progs/msg/en/helptab.msg
                     textes de HELP.COM, par page, compressés en LZSS
                     (tools/lzhir.py, format de archives/lzss-osdk), et
                     tables des mots ; décodés par help.s, qui les inclut
                     comme ses messages (build.sh : -I msg/fr ou en)

HELP est un index : « HELP mot » montre la page du mot.
- Mots généraux : le nom d'une page et ses mots (noms de commandes,
  synonymes). Toute commande (interne, de src/ccp.s ; .COM, de progs/*.s ;
  script livré) doit avoir le sien : sinon, erreur.
- Vocabulaire d'une page (GRAPHER, LOGO) : ses sous-pages, une par thème.
  « HELP GRAPHER mot » montre la sous-page du mot ; les mots d'une sous-page
  sont ceux, en majuscules, de sa colonne de gauche, plus ceux qu'elle
  déclare (cités à droite : FBOX, NEXT...). La page principale se termine
  par la liste des mots, par thème. Un mot hors de son vocabulaire n'existe
  pas (« HELP PLOT » : mot inconnu dans ce contexte) : deux vocabulaires
  peuvent avoir les mêmes mots (SAVE : commande, GRAPHER, LOGO).
- Une page vise deux écrans (MAXL lignes : 25 sous la commande, puis 25
  après la pause, sans seconde pause avant le prompt) ; celles qui
  dépassent sont signalées, trois écrans (MAXL3) sont le maximum.

  gen_readme_txt.py             écrit les quatre fichiers
  gen_readme_txt.py --verifie   n'écrit rien ; erreur s'ils ne sont pas à
                                jour (build.sh)

Lisible sur l'écran de l'Oric (37 colonnes au plus, sans accents).
Deux colonnes : commande et paramètres | libellé court. Ce qui dépasse
passe à la ligne suivante, décalé. Une ligne (None, texte) occupe toute la
largeur."""
import glob
import os
import re
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lzhir

W = 37          # largeur maximale (38 colonnes utiles, la 38e ferait sauter une ligne)
LW = 14         # largeur de la colonne de gauche
RW = W - LW - 2 # à droite de "| "
MAXL = 50       # lignes d'une page, titre compris : deux écrans (visé)
MAXL3 = 76      # trois écrans (maximum)
LOT = 18000     # octets de texte d'un lot de pages, compressé d'un seul tenant

# notation : en tête de README.TXT, à la fin de la page d'accueil de HELP
NOTATION = [
  ("afn", "nom, jokers * et ?"),
  ("fic", "nom de fichier, lecteur facultatif (B:NOM.TXT)"),
  ("adr bb", "hexa : 0500 A9"),
  ("[...]", "facultatif"),
]
NOTATION_EN = [
  ("afn", "name, wildcards * ?"),
  ("file", "file name, drive optional (B:NAME.TXT)"),
  ("adr bb", "hex: 0500 A9"),
  ("[...]", "optional"),
]

# page : (nom, titre, mots, lignes, sous-pages) ; la première est celle de
# HELP seul. Sous-page : (thème, titre, mots généraux, mots en plus, lignes)
PAGES = [
 ("AIDE", "CP/A 0.9 - AIDE", ["HELP"], [
  ("HELP mot", "la page d'une commande ou d'un sujet : HELP COPY, HELP DIS (le debut du mot suffit)"),
  ("FICHIERS", "DIR DIRS TYPE ERA REN COPY STAT SET"),
  ("DISQUES", "B: FORMAT DISKCOPY"),
  ("ECRAN", "CLS PAPER INK PAGE VER SPLIT TEXT GCLS GSAVE GLOAD VOIR VSYNC"),
  ("SCRIPTS", "DO XDO AUTO.BAT ECHO PAUSE PUT"),
  ("TOUCHES", "clavier, ligne de commande"),
  ("EDIT", "editeur de texte"),
  ("CMDER", "fichiers en plein ecran"),
  ("USB", "EXPORT IMPORT USBDIR USBCD USBMOUNT"),
  ("TAP", "cassettes : MKTAP UNTAP"),
  ("RESEAU", "TERM XFER REMOTE HOSTS"),
  ("ASM", "assembleur, desassembleur : ASM DIS"),
  ("DEBUG", "DEBUG SAVE POKE GO"),
  ("MEMOIRE", "carte de la memoire : MEM"),
  ("HEX", "editeur hexadecimal"),
  ("EDSPRITE", "editeur de sprites"),
  ("GRAPHER", "dessin et jeux (HELP GRAPHER mot : HELP GRAPHER PLOT) ; GRXASM GRXPACK"),
  ("LOGO", "LOGO LOGOTR (HELP LOGO mot : HELP LOGO REPETE)"),
 ], []),
 ("FICHIERS", "FICHIERS", ["DIR", "DIRS", "TYPE", "ERA", "REN", "COPY", "STAT", "SET"], [
  ("DIR [afn]", "liste des fichiers"),
  ("DIRS [afn]", "idem, fichiers SYS compris"),
  ("TYPE fic", "affiche un texte"),
  ("ERA afn [/Q]", "efface, apres confirmation (/Q : sans question)"),
  ("REN anc nouv", "renomme (ou REN nouv=anc, comme CP/M)"),
  ("COPY src [dst]", "copie, jokers admis : COPY *.COM B:, COPY *.TXT *.BAK, COPY B:*.LOG"),
  ("STAT [d:][afn]", "taille : enreg., blocs de 2 Ko, octets ; At : R protege, S systeme ; seul : place libre"),
  ("SET afn [opt]", "attributs : RO RW SYS DIR (sans opt : les affiche)"),
  ("CMDER [d:][afn]", "gestionnaire de fichiers plein ecran : trier, filtrer, marquer, voir, copier... (HELP CMDER)"),
  ("DIRS *.COM", "tous, caches (SYS) compris"),
 ], []),
 ("DISQUES", "DISQUES ET LECTEURS", ["FORMAT", "DISKCOPY", "LECTEURS"], [
  ("B:", "lecteur courant (A: a D:) ; aussi menu Systeme, Lecteur suivant ; un .COM ou .BAT tape sans lecteur est cherche sur le lecteur courant (dans un script : celui du script), puis A:, puis B:, C:, D: deja lus depuis l'allumage (DIR B:...) ; LOCI : tous ceux qui ont une image"),
  ("FORMAT X: [/Q]", "formate X: (A: : un seul lecteur) ; /Q : vide le repertoire"),
  ("DISKCOPY s: d: [opt]", "copie la disquette s: sur d: (A: A: : un seul lecteur) ; /T tout, /V relecture, /S systeme seulement (SYSGEN)"),
 ], []),
 ("ECRAN", "ECRAN ET IMAGES", ["CLS", "PAPER", "INK", "PAGE", "VER", "SPLIT", "TEXT", "GCLS", "GSAVE", "GLOAD", "VOIR", "VSYNC", "GTEST", "IMAGES"], [
  ("CLS", "efface l'ecran"),
  ("PAPER n / INK n", "couleur du fond / de l'encre, 0-7 (0 noir 1 rouge 2 vert 3 jaune 4 bleu 5 magenta 6 cyan 7 blanc)"),
  ("PAGE ON/OFF", "pause en fin d'ecran, ou non (aussi menu Ecran, Pagination)"),
  ("VER", "version"),
  ("SPLIT", "image + 10 lignes"),
  ("TEXT", "texte seul"),
  ("GCLS", "efface l'image"),
  ("GSAVE fic", "sauve l'image (.IMG)"),
  ("GLOAD fic", "charge l'image"),
  ("(dessin)", "PLOT, LINE... : dans GRAPHER (HELP GRAPHER)"),
  ("VOIR nom", "affiche NOM.HIR (plein ecran), .HIZ (compressee) ou .IMG, une touche"),
  ("VOIR nom.ANI [n]", "animation jouee n fois (0 : jusqu'a une touche) ; fleches G D : ligne de dechirure"),
  ("VSYNC", "cale le top 50 Hz sur l'ecran (texte du milieu en entier), jusqu'a l'arret"),
  ("GTEST", "demo graphique"),
 ], []),
 ("SCRIPTS", "SCRIPTS (.BAT)", ["DO", "XDO", "AUTO", "ECHO", "PAUSE", "PUT", "BAT"], [
  ("NOM [param]", "lance NOM.COM, sinon NOM.BAT"),
  ("DO fic [p1..p9]", "lance FIC.BAT ($1..$9 = parametres, ESC arrete)"),
  ("XDO nom [param]", "script appele par un script (lance par le CCP)"),
  ("AUTO.BAT", "sur A:, lance a l'allumage (ESC l'arrete)"),
  ("ECHO texte", "affiche le texte"),
  ("PAUSE [texte]", "attend une touche"),
  ("PUT fic cmd [param]", "lance cmd, copie sa sortie dans fic"),
 ], []),
 ("TOUCHES", "TOUCHES", ["FUNCT", "CTRL", "ESC", "RESET", "CLAVIER", "TOUCHE"], [
  ("FUNCT", "menus deroulants"),
  ("CTRL-T", "majuscules oui/non (voyant A ou a au bout de la barre)"),
  ("<- ->", "deplace dans la ligne (on tape en insertion)"),
  ("haut bas", "lignes deja tapees (historique)"),
  ("^I ESC", "complete un nom de fichier (en debut de ligne : une commande) ; 2 fois : les noms possibles"),
  ("DEL ^D", "efface a gauche / sous"),
  ("^A ^E", "debut / fin de ligne (aussi SHIFT-<- SHIFT->)"),
  ("^U", "efface la ligne"),
  ("CTRL-P", "imprimante oui/non (tout ce qui s'affiche ; voyant P ; aussi menu Systeme)"),
  ("CTRL-C", "(ligne vide du prompt) redemarrage a chaud"),
  ("^I", "CTRL-I, la tabulation (l'Oric n'a pas de touche TAB)"),
  ("RESET", "retour au prompt"),
 ], []),
 ("EDIT", "EDIT [fic] : EDITEUR DE TEXTE", [], [
  ("fleches", "deplacement"),
  ("SHIFT <- ->", "debut / fin de ligne"),
  ("CTRL <- ->", "mot precedent / suivant"),
  ("SHIFT haut bas", "page prec. / suiv."),
  ("CTRL haut bas", "debut / fin du texte"),
  ("DEL ^D", "efface avant / sous"),
  ("^ESPACE", "marque un bout du bloc (ESC ote la marque)"),
  ("^X ^C ^V", "coupe / copie le bloc (marque..curseur) / colle"),
  ("^K", "efface le paragraphe"),
  ("^E", "insere / remplace"),
  ("^F ^G ^H", "cherche / suivant / remplace"),
  ("^O ^S ^Q", "ouvre / enregistre / quitte"),
  ("^I (TAB)", "insere un fichier au curseur"),
  ("^P", "imprime le texte, mis en page (ESC arrete)"),
  ("^L", "paragraphe trop long suivant"),
  ("C 127!", "(etat) position dans le paragraphe ; ! : trop long"),
  ("^W", "affichage suivant : coupure mots, a 38 car., ligne entiere (defile en largeur ; < > sur la ligne d'etat)"),
  ("EDIT.CFG", "par fichier : nom maxi [MOTS|CAR|LIGNE] [largeur impr.], ex. *.LOG 126 LIGNE 80 (WORDS, CHAR, LINE aussi)"),
  ("FUNCT", "menus Fichier (dont Inserer, Imprimer), Edition, Chercher, Options"),
 ], []),
 ("CMDER", "CMDER : FICHIERS PLEIN ECRAN", [], [
  ("CMDER [d:][afn]", "fichiers de d:, filtre afn (CMDER B:*.COM)"),
  ("CMDER A: B:", "deux colonnes (A: A: refuse)"),
  ("^I ^W ^Z", "autre colonne / echanger / plein ecran"),
  ("CMDER USB:[ch]", "cle du LOCI (A: USB: : 2 colonnes) ; RETURN entre, .. remonte ; fixe le repertoire courant"),
  ("/R", "(USB) repertoires seuls"),
  ("/T", "(copie de la cle) LF seul -> CR LF, TAB -> espace"),
  ("haut bas", "fichier precedent / suivant"),
  ("<- ->", "page precedente / suivante (aussi SHIFT haut / bas)"),
  ("< >", "premier / dernier fichier (aussi CTRL haut / bas)"),
  ("A a Z", "fichier suivant qui commence par la lettre"),
  ("ESP", "marque / ote la marque"),
  ("+ -", "marque / ote selon un modele (*.COM)"),
  ("*", "inverse les marques"),
  ("1 2 3 4", "tri : disque, nom, type, taille ; 2 fois : ordre inverse"),
  ("/", "filtre (B:*.TXT : autre lecteur)"),
  ("RETURN", "voir le texte"),
  ("^C ^X", "copier / deplacer vers B: ou NOM.EXT ; A: (meme lecteur) : disquettes echangees"),
  ("^N", "renommer"),
  ("DEL", "effacer (confirmation)"),
  ("^U ^O", "(cle) dupliquer / monter une image"),
  ("^A", "attributs R (protege) S (systeme)"),
  ("? ^E", "taille exacte : du fichier / de tous"),
  ("^L ^R", "autre lecteur / relire (disquette changee)"),
  ("FUNCT", "menus Fichier (Imprimer liste, Copier texte), Marque, Trier, Vue (Absents autre : absents de l'autre colonne ou differents)"),
  ("ESC ^Q", "quitter"),
  ("cibles", "les fichiers marques, sinon celui du curseur"),
 ], []),
 ("USB", "USB : CLE DU LOCI", ["EXPORT", "IMPORT", "USBDIR", "USBCD", "USBMOUNT", "CLE"], [
  ("EXPORT fic [nom]", "fic -> cle (nom : par defaut fic, minuscules gardees)"),
  ("EXPORT afn [dos]", "jokers : chaque fichier sous son nom, dans le dossier dos"),
  ("IMPORT nom [fic]", "cle -> fic (par defaut : nom coupe a 8.3 ; B: seul : sur B:)"),
  ("/T", "(IMPORT) texte : LF seul -> CR LF, TAB -> espace"),
  ("USBDIR [ch]", "liste ; /S : supports"),
  ("DOS/X *.DSK", "depuis le repertoire courant ; jokers"),
  ("..  /X  2:/X", "parent ; racine ; cle 2: (0: LOCI)"),
  ("USBCD [rep]", "change de repertoire ; seul : CMDER"),
  ("USBMOUNT [B:]", "images montees ; B: son chemin"),
  ("  B: nom  B: /E", "monte en B: (pas A:) / ejecte"),
  ("  nom.TAP [/B]", "cassette ; /B : puis le BASIC"),
  ("^Z", "retires a l'EXPORT, ajoutes a l'IMPORT"),
  ("X.DSK", "EXPORT refuse (image disque)"),
 ], []),
 ("TAP", "TAP : CASSETTES DE L'ORIC", ["MKTAP", "UNTAP", "CASSETTE"], [
  ("UNTAP JEU", "blocs de JEU.TAP : numero, nom, BAS ou BIN, adresses, /R (lance tout seul)"),
  ("UNTAP JEU 2", "extrait le bloc 2 (* : tous) : BASIC en texte (JEU.BAS, pour EDIT), code en .BIN"),
  ("/1", "(UNTAP) BASIC de l'Oric-1"),
  ("DIS JEU3.BIN adr", "desassemble le code extrait (HELP DIS)"),
  ("MKTAP JEU fic adr [/R]..", "ecrit JEU.TAP : un bloc par fichier, charge en adr (8 au plus) ; /R : lance apres CLOAD\"\""),
  ("MKTAP JEU JEU.BAS /R", "programme BASIC ecrit dans EDIT (sans adresse) ; {hh} : code en hexa"),
  ("ASM nom /T", "assemble en NOM.TAP"),
  ("GRXASM nom /O", "programme GRAPHER en NOM.TAP"),
  ("USBMOUNT JEU.TAP /B", "(cle) lance la cassette sous le BASIC du LOCI"),
 ], []),
 ("RESEAU", "RESEAU : MODEM DU LOCI", ["TERM", "XFER", "REMOTE", "HOSTS", "MODEM"], [
  ("TERM [hote] [/E/L/D/B]", "terminal serie (modem du LOCI) ; hote : appel (fichier HOSTS) ; /E echo, /L CR LF, /D diagnostic, /B sans attente ; ^Q quitte"),
  ("XFER R|E fic [nom] [/T] [@hote]", "recoit (R) ou envoie (E) un fichier par le modem (XMODEM, serveur xfer_server.py) ; /T texte ; @hote : appel (HOSTS)"),
  ("REMOTE hote|/N|OFF", "console a distance : le Mac (tools/remote.py) tape et lit l'ecran ; hote : appel, port 2324 (HOSTS) ; /N sans appel ; OFF coupe ; seul : etat ; voyant R ; Mac muet 10 s : rappel seul"),
  ("HOSTS", "hotes de TERM, XFER et REMOTE : nom adresse[:port], ex. mac 192.168.1.20 (EDIT HOSTS)"),
 ], []),
 ("ASM", "ASM, DIS : ASSEMBLEUR", ["DIS", "HELLO"], [
  ("ASM nom [/S/E/T]", "NOM.ASM -> NOM.COM ; /S : et NOM.SYM ; /E : efface NOM.ASM si tout va bien ; /T : NOM.TAP"),
  ("etiq", "en colonne 1"),
  ("NOM = expr", "constante"),
  ("*= adr", "adresse (0500)"),
  (".byt .asc", "octets, \"chaines\""),
  (".word", "mots 16 bits"),
  (".dsb n[,v]", "n octets"),
  (".(  .)", "bloc, etiquettes locales"),
  ("#include \"f\"", "inclusion (un niveau ; lecteur de la source, puis A: a D:)"),
  ("#lib \"f\",...", "routines de GRX.LIB (ecrit par GRXASM)"),
  ("$ % \"c\" *", "hexa, binaire, car., ici"),
  ("< >", "octet bas / haut"),
  ("HELLO [param]", "exemple de .COM"),
  ("DIS nom [adr]", "desassemble NOM.BIN (ou un .COM, une ROM) : NOM.ASM, qu'ASM reassemble a l'identique ; adr : adresse de chargement (0500 par defaut)"),
  ("/E adr..", "(DIS) points d'entree en plus (8) ; le code qu'il n'atteint pas reste en .byt"),
  ("bloc de .TAP", "(DIS) adr : celle d'UNTAP ; /E : le CALL du chargeur BASIC (CALL#2E00 : /E 2E00)"),
  ("ATMOS.SYM", "(DIS) noms de la ROM et du VIA"),
 ], []),
 ("DEBUG", "DEBUG, SAVE, POKE, GO", ["SAVE", "POKE", "GO"], [
  ("DEBUG nom [param]", "debogueur"),
  ("R [reg=v]", "registres (A X Y S PC P, N V D I Z C)"),
  ("L [adr]", "desassemble"),
  ("D [adr]", "memoire"),
  ("M adr bb..", "modifie la memoire"),
  ("G [adr]", "execute"),
  ("T [n]", "pas a pas"),
  ("P [n]", "pas a pas, JSR d'un coup"),
  ("B [adr]", "pose / liste les points d'arret"),
  ("B- [adr]", "enleve (tous)"),
  ("? expr", "valeur et symbole"),
  ("H  Q", "aide / quitte"),
  ("adr", "hexa, #decimal, nom+n"),
  ("SAVE n fic", "sauve n pages de 0500"),
  ("POKE adr bb..", "ecrit en memoire (code a lancer : 0600 et +)"),
  ("GO adr [param]", "lance le code (RTS = retour)"),
  ("HELP MEMOIRE", "carte de la memoire"),
 ], []),
 ("MEMOIRE", "MEMOIRE", ["MEM"], [
  ("0000-00DF", "page zero libre"),
  ("0200 / 0203", "WBOOT / BDOS"),
  ("020C", "haut de la TPA (mot)"),
  ("0400-04FF", "page de base, DMA 0480"),
  ("0500-B3FF", "programmes (TPA)"),
  ("A000-B3FF", "image en mode SPLIT (TPA jusqu'a 9FFF)"),
  ("B400-BB7F", "jeux de caracteres"),
  ("BB80-BFDF", "ecran texte"),
  ("C000-FFFF", "CP/A (RAM overlay)"),
  ("DEBUG", "se place en 8400-9FFF"),
  ("MEM", "cette carte, selon le mode"),
 ], []),
 ("HEX", "HEX", [], [
  ("HEX fic", "editeur hexadecimal"),
  ("fleches RET", "deplacement"),
  ("SHIFT <- ->", "debut / fin de ligne"),
  ("SHIFT haut bas", "page prec. / suiv."),
  ("CTRL haut bas", "debut / fin du fichier"),
  ("^L", "aller a l'adresse"),
  ("^F ^G", "cherche texte ou #hexa / suivant"),
  ("^I", "mode HEX / ASCII"),
  ("^S ^R", "enregistre / recharge"),
  ("ESC ^Q", "quitte"),
 ], []),
 ("EDSPRITE", "EDSPRITE : SPRITES .SPR", ["SPR"], [
  ("EDSPRITE [nom]", "ouvre ou cree NOM.SPR (GRAPHER)"),
  ("^I", "grille <-> liste des sprites"),
  ("fleches", "grille : un point ; liste : sprite prec. / suiv."),
  ("SHIFT fleches", "bord du caractere / page"),
  ("CTRL fleches", "sprite prec. / suiv., premier / dernier"),
  ("ESP M DEL", "point plein, masque, transparent"),
  ("P", "crayon : pose en se deplacant ; P ou ESC le leve"),
  ("S M", "(liste) voir le sprite ou le masque"),
  ("RETURN", "(liste) dessiner le sprite"),
  ("^H", "octets en hexa / liste et apercu"),
  ("^Z ^X ^C ^V", "annuler, couper, copier, coller"),
  ("^N ^O ^S ^Q", "nouveau, ouvrir, enregistrer, quitter"),
  ("FUNCT", "menus : Sprite (taille...), Dessin (miroirs...), Vue (animer)"),
 ], []),
 ("GRAPHER", "GRAPHER : FICHIERS .GRX", ["GRX"], [
  ("GRAPHER nom [p]", "execute NOM.GRX ($1..$9 = p, ESC arrete a tout moment)"),
  ("nombres", "entiers -32768..32767"),
  ("variables", "A a Z, ou deux car. : PX N1 (sauf IF)"),
  ("parametre", "expression sans espace : X+8 RND(240) (X * 2)"),
  ("operateurs", "- ; * / % ; + - ; = <> < <= > >= ; & |"),
  ("V = expr", "affectation (LET V = expr)"),
  ("; texte", "commentaire"),
 ], [
  ("programme", "GRAPHER : PROGRAMME", [], ["RND", "ABS", "INKEY", "TIMER", "LET", "NEXT", "ELSE", "ENDIF", "ENDSUB", "CALL", "RETURN"], [
   ("fonctions", "RND(n) ABS(n) POINT(x,y) INKEY SCRN(col,lig) LEN(A$) FOUND TILE(x,y) TIMER"),
   ("REPEAT n", "... NEXT"),
   ("FOR V a b [p]", "... NEXT"),
   ("WHILE expr", "... NEXT"),
   ("IF expr", "... [ELSE ...] ENDIF"),
   ("SUB NOM", "... ENDSUB ; CALL NOM ; RETURN"),
   ("PRINT e1 e2 ;", "affiche a la suite nombres, chaines, \"textes\" (PRINT \"V= \" V) ; console : ligne suivante, sauf ; final (;; : commentaire apres) ; LORES : au curseur ; rien en HIRES"),
   ("INPUT A$ / V", "saisie d'une chaine / d'un entier"),
   ("WAIT", "attend une touche"),
   ("GET V", "attend une touche, son code dans V"),
   ("DELAY n", "attend n/50 s"),
   ("ECHO texte", "affiche (pas en HIRES) ; entre guillemets : le texte seul"),
   ("END", "fin ; HIRES et LORES : retour a la console (WAIT avant pour attendre)"),
  ]),
  ("tableaux, fichiers", "GRAPHER : TABLEAUX, FICHIERS", [], ["LEN", "FOUND", "BLOAD"], [
   ("DIM A(n) M$(c,l)", "tableaux d'entiers, d'octets ($) ; nom d'une lettre ; indices 0 a n-1 ; deux dimensions : colonnes puis lignes, comme l'ecran ; tailles constantes, hors de tout bloc : acces rapides une fois traduit"),
   ("A(i) A(c,l)", "element ; M$(c,l) : un code 0-255"),
   ("A$ M$(l)", "chaine (jusqu'au premier 0) : = < > LEN PRINT"),
   ("A$ = \"texte\"", "affectation ; IF A$ = B$ : comparaison"),
   ("FILL A v", "tout le tableau a v"),
   ("SAVE A fic", "tableau en texte (.TXT), une ligne par ligne du tableau ; CR LF ajoutes, codes 1-31 refuses (BSAVE)"),
   ("LOAD A fic", "le relit ; absent : rien ne change, FOUND = 0"),
   ("BSAVE A fic", "tableau en binaire (.DAT), octets a la suite, sans fin de ligne ; BLOAD : le relit"),
   ("BSAVE SCREEN fic", "LORES : l'ecran texte (.SCR) ; BLOAD SCREEN"),
  ]),
  ("dessin", "GRAPHER : DESSIN", [], ["FBOX", "POINT"], [
   ("HIRES", "plein ecran 240 x 200, efface"),
   ("SPLIT", "240 x 128, console dessous"),
   ("TEXT", "retour au texte (console)"),
   ("GCLS", "efface l'image"),
   ("PEN m", "0 efface 1 trace 2 inv."),
   ("PLOT x y", "point (x 0-239, y 0-199)"),
   ("LINE x1 y1 x2 y2", "ligne"),
   ("BOX x1 y1 x2 y2", "rectangle (FBOX : plein)"),
   ("CIRCLE x y r", "cercle"),
   ("PAINT x y", "remplit la zone autour du point (PEN 0 : efface)"),
   ("GTEXT col y texte", "texte dans l'image (col 0-39)"),
   ("ATTR col y1 y2 v", "attribut : encre 0-7, papier 16-23"),
   ("GNUM col y n", "nombre dans l'image"),
   ("GLOAD fic", ".HIR ou .HIZ (HIRES), .IMG (SPLIT)"),
   ("ANIM fic [n]", "animation .ANI en HIRES, n fois (0 : jusqu'a une touche)"),
   ("GSAVE fic", "idem, selon le mode"),
  ]),
  ("ecran texte", "GRAPHER : ECRAN TEXTE (LORES)", [], ["SCRN", "ROTV"], [
   ("LORES", "ecran texte 40 x 28 au programme, sans console ni menus"),
   ("CLS", "LORES : attribut 16 partout ; sinon la console"),
   ("LOCATE col lig", "curseur (col 0-39, lig 0-27)"),
   ("CHAR col lig c", "octet c dans la case (caractere ou attribut)"),
   ("SPC n [x]", "n fois l'octet x (espace par defaut)"),
   ("TAB n", "avance de n colonnes sans ecrire"),
   ("PRINTV ECHOV SPCV", "comme PRINT ECHO SPC, vers le bas (LORES)"),
   ("ECHO \"texte\"", "LORES : au curseur, tel quel ; ECHO seul : ligne suivante ; rien apres la colonne 39"),
   ("PASTE T$(x,y) c l w h", "copie w x h cases de T$ (depuis la colonne x, ligne y) a l'ecran en (c,l)"),
   ("GRAB T$(x,y) c l w h", "l'inverse : de l'ecran vers T$"),
   ("SCROLH n [rect [x]]", "glisse de n cases (n > 0 : a droite) ; rect = c1 l1 c2 l2 ; x : cases liberees"),
   ("SCROLV n [rect [x]]", "idem en hauteur (n > 0 : vers le bas)"),
   ("ROTH n [rect]", "rotation : ce qui sort rentre de l'autre cote ; ROTV : en hauteur"),
  ]),
  ("sprites, tuiles", "GRAPHER : SPRITES, TUILES", [], [], [
   ("SPRITES n", "n emplacements de sprites (0 a n-1)"),
   ("SPOOL T [ALT]", "codes libres pour les sprites (tableau d'entiers T, 32-127 ; ALT : jeu secondaire, 32-111)"),
   ("SSHOW k S$ n c l", "sprite n du .SPR (BLOAD S$ NOM.SPR) en col c, lig l, emplacement k ; deplace ; [ALT]"),
   ("SHIDE k", "retire le sprite de l'emplacement k"),
   ("HSHOW k S$ n c y", "HIRES, SPLIT : sprite n dans l'image, colonne d'octets c, ligne de points y ; decor garde"),
   ("HHIDE k", "HIRES, SPLIT : retire le sprite, le decor revient"),
   ("TILESET D$ w h [K$]", "tuiles de w x h codes (1-4), une par ligne de D$ ; K$ : caracteres de la carte dans l'ordre des tuiles (sinon octet = numero)"),
   ("TMAP T$ x y c l w h", "LORES : carte T$, caractere (x,y) du monde en (c,l), w x h cases ; inconnu ou hors carte : tuile 0"),
   ("TILE(x,y)", "numero de la tuile sous le caractere (x,y) (carte du dernier TMAP)"),
   ("TFONT S$ code [ALT]", "LORES : dessins d'un .SPR de genre 1 dans la police, codes consecutifs"),
  ]),
  ("traduire", "GRAPHER : TRADUIRE", ["GRXASM", "GRXPACK"], [], [
   ("GRXASM nom [p]", "traduit NOM.GRX en NOM.ASM (routines utiles de GRX.LIB, sinon des .INC) ; puis ASM NOM -> NOM.COM"),
   ("GRXASM nom /C [p]", "traduit puis assemble : NOM.COM, NOM.ASM efface"),
   ("GRXASM nom /O [p]", "Oric seul : NOM.TAP (CLOAD\"\") ; ni SPLIT ni SAVE"),
   ("GRAPHER nom /A", "la meme chose : passe la main a GRXASM (/C, /O : et a ASM)"),
   ("GRXPACK nom dest", "ecrit DEST.GRX, le programme sans commentaires, lignes vides ni espaces inutiles : moins de memoire, plus vite en interprete"),
   ("GRXPACK nom /L n", "ligne de NOM.GRX qui a donne la ligne n du programme compact (numero d'une erreur)"),
   ("traduit", "aucun controle a l'execution ; ESC n'arrete rien : INKEY GET WAIT le rendent (27) ; sortie : une autre touche (Q), sinon RESET"),
  ]),
 ]),
 ("LOGO", "LOGO", ["LOGOTR"], [
  ("LOGO [fic]", "Logo et sa tortue (charge fic.LOG)"),
  ("LOGOTR nom [/EN]", "traduit les primitives de NOM.LOG vers l'anglais (/EN) ou le francais (/FR) ; NOM.BAK garde"),
  ("ESC ^C", "interrompt le programme (on reste dans LOGO)"),
  ("AIDE", "liste complete"),
  ("QUITTE", "retour a CP/A"),
 ], [
  ("tortue, dessin", "LOGO : TORTUE, DESSIN", [], ["RECTANGLE", "PAVE", "GOMME"], [
   ("AV n  RE n", "avance / recule (n decimal admis)"),
   ("DR n  GA n", "droite / gauche (degres, 0.5 admis)"),
   ("LC  BC", "leve / baisse stylo"),
   ("CT  MT", "cache / montre"),
   ("VE  ORIGINE", "vide ecran / centre"),
   ("POINT x y", "un point (coordonnees de la tortue, qui ne bouge pas)"),
   ("TRAIT x y x y", "un trait ; RECTANGLE, PAVE (plein) : coins opposes"),
   ("CERCLE r", "autour de la tortue (r 0-127)"),
   ("REMPLIS", "remplit la zone autour de la tortue (GOMME : efface)"),
   ("ETIQUETTE x", "ecrit x dans l'image a la tortue"),
   ("FIXECOULEUR v", "encre 0-7 ou papier 16-23 de l'image"),
   ("ALLUME? x y", "1 si le point est allume"),
  ]),
  ("programmes, calcul, listes", "LOGO : PROGRAMMES, CALCUL, LISTES", [], ["RESTE", "NOMBRE?", "MEMBRE?", "DONNE", "LL"], [
   ("REPETE n [..]", "repete la liste"),
   ("SI c [..] [..]", "condition"),
   ("POUR NOM :A ... FIN", "definit une procedure"),
   ("RENDS x", "la procedure rend x"),
   ("RETOURPROMPT", "arrete tout, retour au prompt ?"),
   ("EC x", "ecrit"),
   ("3.14  2E-7", "decimaux (9 chiffres) ; 7 / 2 = 3.5"),
   ("ENT x  ARRONDI x", "partie entiere / entier proche"),
   ("RACINE x", "racine carree"),
   ("SIN COS ARCTAN", "en degres (SIN 30 = 0.5)"),
   ("LN x  EXP x", "logarithme / exponentielle"),
   ("ABS x", "valeur absolue"),
   ("QUOTIENT a b", "division entiere ; RESTE a b : reste"),
   ("\"MOT  [A B]", "mot, liste (DONNE \"L [A B])"),
   ("PR SP x", "premier / sauf le premier"),
   ("DER SD x", "dernier / sauf le dernier"),
   ("ITEM n x", "n-ieme element"),
   ("COMPTE x", "nombre d'elements"),
   ("MOT a b", "colle deux mots"),
   ("PH a b  LISTE a b", "phrase / liste de deux"),
   ("VIDE? MOT? LISTE?", "1 ou 0 ; aussi NOMBRE? MEMBRE? a b"),
   ("EXEC [..]", "execute une liste"),
  ]),
  ("texte, clavier, fichiers", "LOGO : TEXTE, CLAVIER, FICHIERS", [], ["VIDETEXTE"], [
   ("ECRANTEXTE", "tout en texte"),
   ("ECRANMIXTE", "retour a l'image"),
   ("VT", "efface le texte (VIDETEXTE)"),
   ("TAPE x", "ecrit, sans aller a la ligne"),
   ("FIXECURSEUR c l", "curseur colonne 0-39, ligne 0-27 (ecran entier)"),
   ("FIXECARECRAN c l n", "code n dans la case (attributs 0-31)"),
   ("LISLISTE", "lit une ligne -> liste (LL)"),
   ("LISMOT", "lit une ligne -> mot"),
   ("LISCAR", "attend une touche -> caractere"),
   ("ASCII x  CAR n", "code d'un caractere / caractere"),
   ("TOUCHE?", "1 si une touche attend, 0 sinon"),
   ("TOUCHE", "touche enfoncee, sans delai (jeux) ; mot vide si aucune"),
   ("CURSEUR", "[colonne ligne] du curseur"),
   ("CARECRAN c l", "code de la case"),
   ("SAUVE \"N", "procedures -> N.LOG"),
   ("SAUVEDONNEES \"N [X Y]", "variables globales (toutes, ou celles-la) -> N.LOG en lignes DONNE, relues par CHARGE"),
   ("CHARGE \"N", "charge N.LOG"),
   ("SAUVEIMAGE \"N", "dessin -> N.IMG"),
   ("CHARGEIMAGE \"N", "charge N.IMG"),
  ]),
  ("son", "LOGO : SON", [], [], [
   ("SON v n vol d", "note n (37 = do, 0 = rien) sur la voix v (0-2), volume 0-15 (16 = enveloppe), d/50 s (0 : sans fin)"),
   ("SONF v p vol d", "son de periode p (0-4095)"),
   ("BRUITV v p vol d", "bruit de periode p (0-31)"),
   ("ENVELOPPE f p", "forme 0-15, periode 0-65535"),
   ("MELANGE v s b", "son et bruit de la voix (1 / 0)"),
   ("ENSEMBLE [..]", "les voix de la liste partent ensemble"),
   ("ATTENDSSON v", "attend la fin (255 : toutes)"),
   ("JOUE? v", "1 si la voix joue encore"),
   ("SILENCE", "coupe le son"),
  ]),
 ]),
]

PAGES_EN = [
 ("HELP", "CP/A 0.9 - HELP", [], [
  ("HELP word", "the page of a command or of a topic: HELP COPY, HELP DIS (the start of the word is enough)"),
  ("FILES", "DIR DIRS TYPE ERA REN COPY STAT SET"),
  ("DISKS", "B: FORMAT DISKCOPY"),
  ("SCREEN", "CLS PAPER INK PAGE VER SPLIT TEXT GCLS GSAVE GLOAD VOIR VSYNC"),
  ("SCRIPTS", "DO XDO AUTO.BAT ECHO PAUSE PUT"),
  ("KEYS", "keyboard, command line"),
  ("EDIT", "text editor"),
  ("CMDER", "full-screen files"),
  ("USB", "EXPORT IMPORT USBDIR USBCD USBMOUNT"),
  ("TAP", "tapes: MKTAP UNTAP"),
  ("NETWORK", "TERM XFER REMOTE HOSTS"),
  ("ASM", "assembler, disassembler: ASM DIS"),
  ("DEBUG", "DEBUG SAVE POKE GO"),
  ("MEMORY", "memory map: MEM"),
  ("HEX", "hex editor"),
  ("EDSPRITE", "sprite editor"),
  ("GRAPHER", "drawing and games (HELP GRAPHER word: HELP GRAPHER PLOT); GRXASM GRXPACK"),
  ("LOGO", "LOGO LOGOTR (HELP LOGO word: HELP LOGO REPEAT)"),
 ], []),
 ("FILES", "FILES", ["DIR", "DIRS", "TYPE", "ERA", "REN", "COPY", "STAT", "SET"], [
  ("DIR [afn]", "list of files"),
  ("DIRS [afn]", "same, SYS files included"),
  ("TYPE file", "shows a text"),
  ("ERA afn [/Q]", "erases, after confirmation (/Q: no question)"),
  ("REN old new", "renames (or REN new=old, as in CP/M)"),
  ("COPY src [dst]", "copy, wildcards allowed: COPY *.COM B:, COPY *.TXT *.BAK, COPY B:*.LOG"),
  ("STAT [d:][afn]", "size: records, 2 KB blocks, bytes; At: R read-only, S system; alone: free space"),
  ("SET afn [opt]", "attributes: RO RW SYS DIR (no opt: shows them)"),
  ("CMDER [d:][afn]", "full-screen file manager: sort, filter, mark, view, copy... (HELP CMDER)"),
  ("DIRS *.COM", "all of them, hidden (SYS) included"),
 ], []),
 ("DISKS", "DISKS AND DRIVES", ["FORMAT", "DISKCOPY", "DRIVES"], [
  ("B:", "current drive (A: to D:); also System menu, Next drive; a .COM or .BAT typed without a drive is looked for on the current drive (in a script: the script's), then A:, then B:, C:, D: already read since power-on (DIR B:...); LOCI: all those with an image"),
  ("FORMAT X: [/Q]", "formats X: (A:: a single drive); /Q: empties the directory"),
  ("DISKCOPY s: d: [opt]", "copies disk s: to d: (A: A:: a single drive); /T all, /V read back, /S system only (SYSGEN)"),
 ], []),
 ("SCREEN", "SCREEN AND PICTURES", ["CLS", "PAPER", "INK", "PAGE", "VER", "SPLIT", "TEXT", "GCLS", "GSAVE", "GLOAD", "VOIR", "VSYNC", "GTEST", "PICTURES"], [
  ("CLS", "clears the screen"),
  ("PAPER n / INK n", "background / ink colour, 0-7 (0 black 1 red 2 green 3 yellow 4 blue 5 magenta 6 cyan 7 white)"),
  ("PAGE ON/OFF", "pause at the end of a screen, or not (also Screen menu, Paging)"),
  ("VER", "version"),
  ("SPLIT", "picture + 10 lines"),
  ("TEXT", "text only"),
  ("GCLS", "clears the picture"),
  ("GSAVE file", "saves the picture (.IMG)"),
  ("GLOAD file", "loads the picture"),
  ("(drawing)", "PLOT, LINE...: in GRAPHER (HELP GRAPHER)"),
  ("VOIR name", "shows NAME.HIR (full screen), .HIZ (compressed) or .IMG, a key"),
  ("VOIR name.ANI [n]", "animation played n times (0: until a key); arrows L R: tearing line"),
  ("VSYNC", "sets the 50 Hz tick on the screen (middle text whole), until stopped"),
  ("GTEST", "graphics demo"),
 ], []),
 ("SCRIPTS", "SCRIPTS (.BAT)", ["DO", "XDO", "AUTO", "ECHO", "PAUSE", "PUT", "BAT"], [
  ("NAME [param]", "runs NAME.COM, else NAME.BAT"),
  ("DO file [p1..p9]", "runs FILE.BAT ($1..$9 = parameters, ESC stops)"),
  ("XDO name [param]", "script called by a script (run by the CCP)"),
  ("AUTO.BAT", "on A:, run at power-on (ESC stops it)"),
  ("ECHO text", "shows the text"),
  ("PAUSE [text]", "waits for a key"),
  ("PUT file cmd [param]", "runs cmd, copies its output to file"),
 ], []),
 ("KEYS", "KEYS", ["FUNCT", "CTRL", "ESC", "RESET", "KEYBOARD", "KEY"], [
  ("FUNCT", "pull-down menus"),
  ("CTRL-T", "capitals on/off (A or a indicator at the end of the bar)"),
  ("<- ->", "move in the line (typing inserts)"),
  ("up down", "lines already typed (history)"),
  ("^I ESC", "completes a file name (at the start of the line: a command); twice: the possible names"),
  ("DEL ^D", "erase left / under"),
  ("^A ^E", "start / end of line (also SHIFT-<- SHIFT->)"),
  ("^U", "erases the line"),
  ("CTRL-P", "printer on/off (everything displayed; P indicator; also System menu)"),
  ("CTRL-C", "(empty prompt line) warm restart"),
  ("^I", "CTRL-I, the tab (the Oric has no TAB key)"),
  ("RESET", "back to the prompt"),
 ], []),
 ("EDIT", "EDIT [file]: TEXT EDITOR", [], [
  ("arrows", "move"),
  ("SHIFT <- ->", "start / end of line"),
  ("CTRL <- ->", "previous / next word"),
  ("SHIFT up down", "prev. / next page"),
  ("CTRL up down", "start / end of the text"),
  ("DEL ^D", "erase before / under"),
  ("^SPACE", "marks one end of the block (ESC removes the mark)"),
  ("^X ^C ^V", "cut / copy the block (mark..cursor) / paste"),
  ("^K", "erases the paragraph"),
  ("^E", "insert / overwrite"),
  ("^F ^G ^H", "find / next / replace"),
  ("^O ^S ^Q", "open / save / quit"),
  ("^I (TAB)", "inserts a file at the cursor"),
  ("^P", "prints the text, laid out (ESC stops)"),
  ("^L", "next paragraph that is too long"),
  ("C 127!", "(status line) position in the paragraph; !: longer than the maximum"),
  ("^W", "next display: word wrap, at 38 chars, whole line (scrolls sideways; < > on the status line)"),
  ("EDIT.CFG", "per file: name max [WORDS|CHAR|LINE] [print width], e.g. *.LOG 126 LINE 80 (MOTS, CAR, LIGNE too)"),
  ("FUNCT", "menus File (with Insert, Print), Edit, Search, Options"),
 ], []),
 ("CMDER", "CMDER: FULL-SCREEN FILES", [], [
  ("CMDER [d:][afn]", "files of d:, filter afn (CMDER B:*.COM)"),
  ("CMDER A: B:", "two panels (A: A: refused)"),
  ("^I ^W ^Z", "other panel / swap / full screen"),
  ("CMDER USB:[path]", "the LOCI's stick (A: USB:: 2 panels); RETURN enters, .. goes up; leaves the current directory"),
  ("/R", "(USB) directories only"),
  ("/T", "(copy from the stick) LF alone -> CR LF, TAB -> space; menu Copy as text"),
  ("up down", "previous / next file"),
  ("<- ->", "previous / next page (also SHIFT up / down)"),
  ("< >", "first / last file (also CTRL up / down)"),
  ("A to Z", "next file starting with the letter"),
  ("SPACE", "marks / unmarks"),
  ("+ -", "marks / unmarks by a pattern (*.COM)"),
  ("*", "inverts the marks"),
  ("1 2 3 4", "sort: disk, name, type, size; twice: reverse order"),
  ("/", "filter (B:*.TXT: other drive)"),
  ("RETURN", "view the text"),
  ("^C ^X", "copy / move to B: or NAME.EXT; A: (drive of the list): a single drive, disks swapped"),
  ("^N", "rename"),
  ("DEL", "erase (confirmation)"),
  ("^U ^O", "(stick) duplicate / mount an image"),
  ("^A", "attributes R (read-only) S (system)"),
  ("? ^E", "exact size: of the file / of all"),
  ("^L ^R", "other drive / read again (disk changed)"),
  ("FUNCT", "menus File (Print list), Mark, Sort, View (Not on other: files missing from the other panel or different)"),
  ("ESC ^Q", "quit"),
  ("targets", "the marked files, else the one at the cursor"),
 ], []),
 ("USB", "USB: THE LOCI'S STICK", ["EXPORT", "IMPORT", "USBDIR", "USBCD", "USBMOUNT", "STICK"], [
  ("EXPORT file [name]", "file -> stick (name: file by default, lower case kept)"),
  ("EXPORT afn [dir]", "wildcards: each file under its name, in folder dir"),
  ("IMPORT name [file]", "stick -> file (default: name cut to 8.3; B: alone: on B:)"),
  ("/T", "(IMPORT) text: LF alone -> CR LF, TAB -> space"),
  ("USBDIR [path]", "list; /S: devices"),
  ("DIR/X *.DSK", "from the current directory; wildcards"),
  ("..  /X  2:/X", "parent; root; stick 2: (0: LOCI)"),
  ("USBCD [dir]", "changes directory; alone: CMDER"),
  ("USBMOUNT [B:]", "mounted images; B: its path"),
  ("  B: name  B: /E", "mounts in B: (not A:) / ejects"),
  ("  name.TAP [/B]", "tape; /B: then BASIC"),
  ("^Z", "removed by EXPORT, added by IMPORT"),
  ("X.DSK", "EXPORT refuses (disk image)"),
 ], []),
 ("TAP", "TAP: ORIC TAPES", ["MKTAP", "UNTAP", "TAPES"], [
  ("UNTAP GAME", "blocks of GAME.TAP: number, name, BAS or BIN, addresses, /R (runs by itself)"),
  ("UNTAP GAME 2", "extracts block 2 (*: all): BASIC as text (GAME.BAS, for EDIT), code as .BIN"),
  ("/1", "(UNTAP) Oric-1 BASIC"),
  ("DIS GAME3.BIN adr", "disassembles the extracted code (HELP DIS)"),
  ("MKTAP GAME file adr [/R]..", "writes GAME.TAP: one block per file, loaded at adr (8 at most); /R: run after CLOAD\"\""),
  ("MKTAP GAME GAME.BAS /R", "BASIC program written in EDIT (no address); {hh}: code in hex"),
  ("ASM name /T", "assembles to NAME.TAP"),
  ("GRXASM name /O", "GRAPHER program to NAME.TAP"),
  ("USBMOUNT GAME.TAP /B", "(stick) runs the tape under the LOCI's BASIC"),
 ], []),
 ("NETWORK", "NETWORK: THE LOCI'S MODEM", ["TERM", "XFER", "REMOTE", "HOSTS", "MODEM"], [
  ("TERM [host] [/E/L/D/B]", "serial terminal (LOCI's modem); host: call (HOSTS file); /E echo, /L CR LF, /D diagnostic, /B no wait; ^Q quits"),
  ("XFER R|S file [name] [/T] [@host]", "receives (R) or sends (S) a file over the modem (XMODEM, xfer_server.py server); /T text; @host: call (HOSTS)"),
  ("REMOTE host|/N|OFF", "remote console: the Mac (tools/remote.py) types and reads the screen; host: call, port 2324 (HOSTS); /N no call; OFF cuts; alone: state; R light; Mac silent 10 s: redials"),
  ("HOSTS", "hosts for TERM, XFER and REMOTE: name address[:port], e.g. mac 192.168.1.20 (EDIT HOSTS)"),
 ], []),
 ("ASM", "ASM, DIS: ASSEMBLER", ["DIS", "HELLO"], [
  ("ASM name [/S/E/T]", "NAME.ASM -> NAME.COM; /S: and NAME.SYM; /E: erases NAME.ASM if all goes well; /T: NAME.TAP"),
  ("label", "in column 1"),
  ("NAME = expr", "constant"),
  ("*= adr", "address (0500)"),
  (".byt .asc", "bytes, \"strings\""),
  (".word", "16-bit words"),
  (".dsb n[,v]", "n bytes"),
  (".(  .)", "block, local labels"),
  ("#include \"f\"", "inclusion (one level; drive of the source, then A: to D:)"),
  ("#lib \"f\",...", "routines of GRX.LIB (written by GRXASM)"),
  ("$ % \"c\" *", "hex, binary, char, here"),
  ("< >", "low / high byte"),
  ("HELLO [param]", "example .COM"),
  ("DIS name [adr]", "disassembles NAME.BIN (or a .COM, a ROM): NAME.ASM, which ASM reassembles identically; adr: load address (0500 by default)"),
  ("/E adr..", "(DIS) more entry points (8); the code it does not reach stays as .byt"),
  ("block of a .TAP", "(DIS) adr: the one from UNTAP; /E: the CALL of the BASIC loader (CALL#2E00: /E 2E00)"),
  ("ATMOS.SYM", "(DIS) names of the ROM and the VIA"),
 ], []),
 ("DEBUG", "DEBUG, SAVE, POKE, GO", ["SAVE", "POKE", "GO"], [
  ("DEBUG name [param]", "debugger"),
  ("R [reg=v]", "registers (A X Y S PC P, N V D I Z C)"),
  ("L [adr]", "disassembles"),
  ("D [adr]", "memory"),
  ("M adr bb..", "changes memory"),
  ("G [adr]", "runs"),
  ("T [n]", "single step"),
  ("P [n]", "single step, JSR in one go"),
  ("B [adr]", "sets / lists breakpoints"),
  ("B- [adr]", "removes (all)"),
  ("? expr", "value and symbol"),
  ("H  Q", "help / quit"),
  ("adr", "hex, #decimal, name+n"),
  ("SAVE n file", "saves n pages from 0500"),
  ("POKE adr bb..", "writes to memory (code to run: 0600 and up)"),
  ("GO adr [param]", "runs the code (RTS = return)"),
  ("HELP MEMORY", "memory map"),
 ], []),
 ("MEMORY", "MEMORY", ["MEM"], [
  ("0000-00DF", "free zero page"),
  ("0200 / 0203", "WBOOT / BDOS"),
  ("020C", "top of the TPA (word)"),
  ("0400-04FF", "base page, DMA 0480"),
  ("0500-B3FF", "programs (TPA)"),
  ("A000-B3FF", "picture in SPLIT mode (TPA up to 9FFF)"),
  ("B400-BB7F", "character sets"),
  ("BB80-BFDF", "text screen"),
  ("C000-FFFF", "CP/A (overlay RAM)"),
  ("DEBUG", "sits at 8400-9FFF"),
  ("MEM", "this map, according to the mode"),
 ], []),
 ("HEX", "HEX", [], [
  ("HEX file", "hex editor"),
  ("arrows RET", "move"),
  ("SHIFT <- ->", "start / end of line"),
  ("SHIFT up down", "prev. / next page"),
  ("CTRL up down", "start / end of the file"),
  ("^L", "go to the address"),
  ("^F ^G", "find text or #hex / next"),
  ("^I", "HEX / ASCII mode"),
  ("^S ^R", "save / reload"),
  ("ESC ^Q", "quit"),
 ], []),
 ("EDSPRITE", "EDSPRITE: .SPR SPRITES", ["SPR"], [
  ("EDSPRITE [name]", "opens or creates NAME.SPR (GRAPHER)"),
  ("^I", "grid <-> sprite list"),
  ("arrows", "grid: one dot; list: previous / next sprite"),
  ("SHIFT arrows", "edge of the character / page"),
  ("CTRL arrows", "previous / next sprite, first / last"),
  ("SPC M DEL", "dot solid, mask, clear"),
  ("P", "pen: draws while moving; P or ESC lifts it"),
  ("S M", "(list) view the sprite or the mask"),
  ("RETURN", "(list) draw the sprite"),
  ("^H", "bytes in hex / list and preview"),
  ("^Z ^X ^C ^V", "undo, cut, copy, paste"),
  ("^N ^O ^S ^Q", "new, open, save, quit"),
  ("FUNCT", "menus: Sprite (size...), Draw (flips...), View (animate)"),
 ], []),
 ("GRAPHER", "GRAPHER: .GRX FILES", ["GRX"], [
  ("GRAPHER name [p]", "runs NAME.GRX ($1..$9 = p, ESC stops at any time)"),
  ("numbers", "integers -32768..32767"),
  ("variables", "A to Z, or two chars: PX N1 (except IF)"),
  ("parameter", "expression without spaces: X+8 RND(240) (X * 2)"),
  ("operators", "- ; * / % ; + - ; = <> < <= > >= ; & |"),
  ("V = expr", "assignment (LET V = expr)"),
  ("; text", "comment"),
 ], [
  ("program", "GRAPHER: PROGRAM", [], ["RND", "ABS", "INKEY", "TIMER", "LET", "NEXT", "ELSE", "ENDIF", "ENDSUB", "CALL", "RETURN"], [
   ("functions", "RND(n) ABS(n) POINT(x,y) INKEY SCRN(col,lin) LEN(A$) FOUND TILE(x,y) TIMER"),
   ("REPEAT n", "... NEXT"),
   ("FOR V a b [s]", "... NEXT"),
   ("WHILE expr", "... NEXT"),
   ("IF expr", "... [ELSE ...] ENDIF"),
   ("SUB NAME", "... ENDSUB ; CALL NAME ; RETURN"),
   ("PRINT e1 e2 ;", "shows one after the other numbers, strings, \"texts\" (PRINT \"V= \" V); console: next line, except with a final ; (;; : comment after); LORES: at the cursor; nothing in HIRES"),
   ("INPUT A$ / V", "input of a string / an integer"),
   ("WAIT", "waits for a key"),
   ("GET V", "waits for a key, its code in V"),
   ("DELAY n", "waits n/50 s"),
   ("ECHO text", "shows (not in HIRES); within quotes: the text alone"),
   ("END", "end; HIRES and LORES: back to the console (WAIT before it to wait)"),
  ]),
  ("arrays, files", "GRAPHER: ARRAYS, FILES", [], ["LEN", "FOUND", "BLOAD"], [
   ("DIM A(n) M$(c,l)", "arrays of integers, of bytes ($); one-letter name; indices 0 to n-1; two dimensions: columns then lines, like the screen; constant sizes, outside any block: fast access once translated"),
   ("A(i) A(c,l)", "element; M$(c,l): a code 0-255"),
   ("A$ M$(l)", "string (up to the first 0): = < > LEN PRINT"),
   ("A$ = \"text\"", "assignment; IF A$ = B$: comparison"),
   ("FILL A v", "the whole array to v"),
   ("SAVE A file", "array as text (.TXT), one line per array line; CR LF added, codes 1-31 refused (BSAVE)"),
   ("LOAD A file", "reads it back; missing: nothing changes, FOUND = 0"),
   ("BSAVE A file", "array in binary (.DAT), bytes one after another, no line ends; BLOAD: reads it back"),
   ("BSAVE SCREEN file", "LORES: the text screen (.SCR); BLOAD SCREEN"),
  ]),
  ("drawing", "GRAPHER: DRAWING", [], ["FBOX", "POINT"], [
   ("HIRES", "full screen 240 x 200, cleared"),
   ("SPLIT", "240 x 128, console below"),
   ("TEXT", "back to text (console)"),
   ("GCLS", "clears the picture"),
   ("PEN m", "0 erases 1 draws 2 inverts"),
   ("PLOT x y", "point (x 0-239, y 0-199)"),
   ("LINE x1 y1 x2 y2", "line"),
   ("BOX x1 y1 x2 y2", "rectangle (FBOX: filled)"),
   ("CIRCLE x y r", "circle"),
   ("PAINT x y", "fills the area around the point (PEN 0: erases)"),
   ("GTEXT col y text", "text in the picture (col 0-39)"),
   ("ATTR col y1 y2 v", "attribute: ink 0-7, paper 16-23"),
   ("GNUM col y n", "number in the picture"),
   ("GLOAD file", ".HIR or .HIZ (HIRES), .IMG (SPLIT)"),
   ("ANIM file [n]", ".ANI animation in HIRES, n times (0: until a key)"),
   ("GSAVE file", "same, according to the mode"),
  ]),
  ("text screen", "GRAPHER: TEXT SCREEN (LORES)", [], ["SCRN", "ROTV"], [
   ("LORES", "40 x 28 text screen for the program, no console or menus"),
   ("CLS", "LORES: attribute 16 everywhere; else the console"),
   ("LOCATE col lin", "cursor (col 0-39, lin 0-27)"),
   ("CHAR col lin c", "byte c in the cell (character or attribute)"),
   ("SPC n [x]", "n times byte x (space by default)"),
   ("TAB n", "moves n columns on without writing"),
   ("PRINTV ECHOV SPCV", "like PRINT ECHO SPC, downwards (LORES)"),
   ("ECHO \"text\"", "LORES: at the cursor, as is; ECHO alone: next line; nothing past column 39"),
   ("PASTE T$(x,y) c l w h", "copies w x h cells of T$ (from column x, line y) to the screen at (c,l)"),
   ("GRAB T$(x,y) c l w h", "the reverse: from the screen to T$"),
   ("SCROLH n [rect [x]]", "slides by n cells (n > 0: right); rect = c1 l1 c2 l2; x: freed cells"),
   ("SCROLV n [rect [x]]", "same in height (n > 0: down)"),
   ("ROTH n [rect]", "rotation: what goes out comes back on the other side; ROTV: in height"),
  ]),
  ("sprites, tiles", "GRAPHER: SPRITES, TILES", [], [], [
   ("SPRITES n", "n sprite slots (0 to n-1)"),
   ("SPOOL T [ALT]", "free codes for the sprites (integer array T, 32-127; ALT: secondary set, 32-111)"),
   ("SSHOW k S$ n c l", "sprite n of the .SPR (BLOAD S$ NAME.SPR) at col c, lin l, slot k; moves; [ALT]"),
   ("SHIDE k", "removes the sprite of slot k"),
   ("HSHOW k S$ n c y", "HIRES, SPLIT: sprite n in the picture, byte column c, dot line y; scenery kept"),
   ("HHIDE k", "HIRES, SPLIT: removes the sprite, the scenery comes back"),
   ("TILESET D$ w h [K$]", "tiles of w x h codes (1-4), one per line of D$; K$: map characters in tile order (else byte = number)"),
   ("TMAP T$ x y c l w h", "LORES: map T$, character (x,y) of the world at (c,l), w x h cells; unknown or off the map: tile 0"),
   ("TILE(x,y)", "number of the tile under character (x,y) (map of the last TMAP)"),
   ("TFONT S$ code [ALT]", "LORES: drawings of a kind 1 .SPR into the font, consecutive codes"),
  ]),
  ("translating", "GRAPHER: TRANSLATING", ["GRXASM", "GRXPACK"], [], [
   ("GRXASM name [p]", "translates NAME.GRX into NAME.ASM (useful routines of GRX.LIB, else of the .INC files); then ASM NAME -> NAME.COM"),
   ("GRXASM name /C [p]", "translates then assembles: NAME.COM, NAME.ASM erased"),
   ("GRXASM name /O [p]", "bare Oric: NAME.TAP (CLOAD\"\"); no SPLIT or SAVE"),
   ("GRAPHER name /A", "the same: hands over to GRXASM (/C, /O: and to ASM)"),
   ("GRXPACK name dest", "writes DEST.GRX, the program without comments, blank lines or useless spaces: less memory, faster when interpreted"),
   ("GRXPACK name /L n", "line of NAME.GRX that gave line n of the compact program (number in an error)"),
   ("translated", "no checks while running; ESC stops nothing: INKEY GET WAIT return it (27); exit: another key (Q), else RESET"),
  ]),
 ]),
 ("LOGO", "LOGO", ["LOGOTR"], [
  ("LOGO [file]", "Logo and its turtle (loads file.LOG)"),
  ("LOGOTR name [/FR]", "translates the primitives of NAME.LOG into French (/FR) or English (/EN); NAME.BAK kept"),
  ("ESC ^C", "interrupts the program (stays in LOGO)"),
  ("HELP", "full list"),
  ("BYE", "back to CP/A (also QUIT)"),
 ], [
  ("turtle, drawing", "LOGO: TURTLE, DRAWING", [], ["RECTANGLE", "FILLRECT", "PENERASE"], [
   ("FD n  BK n", "forward / back (decimal n allowed)"),
   ("RT n  LT n", "right / left (degrees, 0.5 allowed)"),
   ("PU  PD", "pen up / down"),
   ("HT  ST", "hide / show turtle"),
   ("CS  HOME", "clear screen / centre"),
   ("DOT x y", "a point (turtle coordinates; it does not move)"),
   ("LINE x y x y", "a line; RECTANGLE, FILLRECT (filled): opposite corners"),
   ("CIRCLE r", "around the turtle (r 0-127)"),
   ("FILL", "fills the area around the turtle (PENERASE: erases)"),
   ("LABEL x", "writes x in the picture at the turtle"),
   ("SETCOLOR v", "ink 0-7 or paper 16-23 of the picture"),
   ("DOT? x y", "1 if the point is lit"),
  ]),
  ("programs, numbers, lists", "LOGO: PROGRAMS, NUMBERS, LISTS", [], ["OP", "PRINT", "REMAINDER", "MAKE", "BUTFIRST", "BUTLAST", "NUMBER?", "MEMBER?"], [
   ("REPEAT n [..]", "repeats the list"),
   ("IF c [..] [..]", "condition"),
   ("TO NAME :A ... END", "defines a procedure"),
   ("OUTPUT x", "the procedure outputs x (OP)"),
   ("TOPLEVEL", "stops all, back to the ? prompt"),
   ("PR x", "prints (PRINT)"),
   ("3.14  2E-7", "decimals (9 digits); 7 / 2 = 3.5"),
   ("INT x  ROUND x", "integer part / nearest integer"),
   ("SQRT x", "square root"),
   ("SIN COS ARCTAN", "in degrees (SIN 30 = 0.5)"),
   ("LN x  EXP x", "logarithm / exponential"),
   ("ABS x", "absolute value"),
   ("QUOTIENT a b", "integer division; REMAINDER a b: remainder"),
   ("\"WORD  [A B]", "word, list (MAKE \"L [A B])"),
   ("FIRST BF x", "first / all but first (BUTFIRST)"),
   ("LAST BL x", "last / all but last (BUTLAST)"),
   ("ITEM n x", "n-th element"),
   ("COUNT x", "number of elements"),
   ("WORD a b", "joins two words"),
   ("SE a b  LIST a b", "sentence / list of two"),
   ("EMPTY? WORD? LIST?", "1 or 0; also NUMBER? MEMBER? a b"),
   ("RUN [..]", "runs a list"),
  ]),
  ("text, keyboard, files", "LOGO: TEXT, KEYBOARD, FILES", [], ["TS", "SS", "CLEARTEXT", "RL", "RW", "RC"], [
   ("TEXTSCREEN", "all text (TS)"),
   ("SPLITSCREEN", "back to the picture (SS)"),
   ("CT", "clears the text (CLEARTEXT)"),
   ("TYPE x", "writes, without a new line"),
   ("SETCURSOR c l", "cursor column 0-39, line 0-27 (whole screen)"),
   ("SETCELL c l n", "code n in the cell (attributes 0-31)"),
   ("READLIST", "reads a line -> list (RL)"),
   ("READWORD", "reads a line -> word (RW)"),
   ("READCHAR", "waits for a key -> character (RC)"),
   ("ASCII x  CHAR n", "code of a character / character"),
   ("KEY?", "1 if a key is waiting, 0 otherwise"),
   ("KEY", "key pressed, no delay (games); empty word if none"),
   ("CURSOR", "[column line] of the cursor"),
   ("CELL c l", "code of the cell"),
   ("SAVE \"N", "procedures -> N.LOG"),
   ("SAVEDATA \"N [X Y]", "global variables (all, or those) -> N.LOG as MAKE lines, read back by LOAD"),
   ("LOAD \"N", "loads N.LOG"),
   ("SAVEPIC \"N", "drawing -> N.IMG"),
   ("LOADPIC \"N", "loads N.IMG"),
  ]),
  ("sound", "LOGO: SOUND", [], [], [
   ("NOTE v n vol d", "note n (37 = C, 0 = none) on voice v (0-2), volume 0-15 (16 = envelope), d/50 s (0: endless)"),
   ("TONE v p vol d", "sound of period p (0-4095)"),
   ("NOISE v p vol d", "noise of period p (0-31)"),
   ("ENVELOPE f p", "shape 0-15, period 0-65535"),
   ("MIX v s n", "sound and noise of the voice (1 / 0)"),
   ("TOGETHER [..]", "the voices of the list start together"),
   ("WAITSOUND v", "waits for the end (255: all)"),
   ("PLAYING? v", "1 if the voice is still playing"),
   ("SILENCE", "stops the sound"),
  ]),
 ]),
]

def wrap(text, first, rest):
    out, cur, width = [], "", first
    for w in text.split():
        if cur and len(cur) + 1 + len(w) > width:
            out.append(cur); cur = w; width = rest
        else:
            cur = (cur + " " + w) if cur else w
    out.append(cur)
    return out

def render(title, rows):
    out = [title, "-" * len(title)]
    for left, right in rows:
        if left is None:                        # toute la largeur
            parts = wrap(right, W, W - 2)
            out.append(parts[0])
            out.extend("  " + q for q in parts[1:])
            continue
        rparts = wrap(right, RW, RW - 2)
        if len(left) > LW - 1:                  # commande trop longue : seule
            out.append(left)
            out.append(" " * LW + "| " + rparts[0])
        else:
            out.append(left.ljust(LW) + "| " + rparts[0])
        for q in rparts[1:]:                    # suite du libellé, décalée
            out.append(" " * LW + "|   " + q)
    for l in out:
        assert len(l) <= W, l
    return out


def text(lines):
    return "".join(l + "\r\n" for l in lines).encode("ascii") + b"\0"


# par langue : pages, notation, textes, fichiers produits
LANGUES = {
    "fr": dict(pages=PAGES, notation=NOTATION, titre="CP/A 0.9 - AIDE-MEMOIRE",
               aide=["Aide : HELP (la liste des pages)", "HELP COPY, HELP DIS... : la page",
                     "d'une commande (debut du mot admis)"],
               mot="HELP %s mot : la page du mot (HELP %s %s)", sep=" : ",
               inconnu="Mot inconnu dans ce contexte.",
               readme="files/readme.txt", tab="progs/msg/fr/helptab.msg",
               langue="français", autre="en"),
    "en": dict(pages=PAGES_EN, notation=NOTATION_EN, titre="CP/A 0.9 - QUICK REFERENCE",
               aide=["Help: HELP (the list of pages)", "HELP COPY, HELP DIS...: the page",
                     "of a command (start of word allowed)"],
               mot="HELP %s word: the page of the word (HELP %s %s)", sep=": ",
               inconnu="Unknown word in this context.",
               readme="files/en/readme.txt", tab="progs/msg/en/helptab.msg",
               langue="anglais", autre="fr"),
}
RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PAS_UN_MOT = ("NOM", "NAME", "HELP")    # dans une colonne de gauche : pas un mot

assert len(PAGES) == len(PAGES_EN)
for (nf, tf, mf, rf, sf), (ne, te, me, re_, se) in zip(PAGES, PAGES_EN):
    assert len(rf) == len(re_) and len(sf) == len(se), (nf, ne)
    for a, b in zip(sf, se):
        assert len(a[4]) == len(b[4]) and a[2] == b[2], (nf, a[0], b[0])


def commandes():
    """noms que HELP doit connaître : commandes internes (table de src/ccp.s),
    programmes (progs/*.s), scripts livrés (files/*.bat)"""
    ccp = open(os.path.join(RACINE, "src", "ccp.s"), encoding="utf-8").read()
    table = ccp.split("cmd_table", 2)[2].split(".byt 0", 1)[0]
    noms = [a + b for a, b in re.findall(r'\.asc "([A-Z]+)"\s*\.byt "([A-Z])"\|\$80', table)]
    assert len(noms) > 10, "table des commandes internes non reconnue"
    for p in glob.glob(os.path.join(RACINE, "progs", "*.s")):
        n = os.path.basename(p)[:-2]
        if not n.endswith(("_tab", "_inc")):
            noms.append(n.upper())
    for p in glob.glob(os.path.join(RACINE, "files", "*.bat")):
        n = os.path.basename(p)[:-4].upper()
        if n != "DEMO":                         # le script de la disquette de démonstration
            noms.append(n)
    return sorted(set(noms))


def releve(rows, exclus):
    """mots en majuscules de la colonne de gauche, dans l'ordre, tels qu'on
    les affiche (ALLUME? garde son ?)"""
    out = []
    for left, right in rows:
        if left is None or left.startswith("HELP "):
            continue
        for t in left.replace("(", " ").split():
            t = t.strip('"[]')
            if re.fullmatch(r"[A-Z][A-Z0-9]+\??", t) and t.rstrip("?") not in exclus and t not in out:
                out.append(t)
    return out


def cle(mot):
    """mot de l'index : 8 lettres au plus (le nom d'un FCB), sans ?"""
    return mot.rstrip("?")[:8]


def table(paires, quoi):
    """[(mot, page)] -> triée, un mot une fois (le premier l'emporte, sauf si
    strict : erreur)"""
    vus, out = {}, []
    for m, p in paires:
        k = cle(m)
        assert re.fullmatch(r"[A-Z][A-Z0-9]*", k), m
        if k in vus:
            assert vus[k] == p or not quoi, "%s : mot en double : %s" % (quoi, m)
            continue
        vus[k] = p
        out.append((k, p))
    return sorted(out)


def structure(code):
    """-> pages à plat [(nom, titre, lignes)] (chaque page principale, suivie
    de ses sous-pages), mots généraux [(mot, page)], vocabulaires
    [(page principale, [(mot, page)])]"""
    L = LANGUES[code]
    plat, general, vocab = [], [], []
    for i, (nom, titre, ms, rows, sous) in enumerate(L["pages"]):
        rows = rows + (L["notation"] if i == 0 else [])
        moi = len(plat)
        general += [(m, moi) for m in [nom] + ms]
        if sous:
            mots = [(m, moi) for m in releve(rows, PAS_UN_MOT + (nom,))]
            fin = []
            for j, (theme, t2, ms2, plus, r2) in enumerate(sous):
                lui = moi + 1 + j
                general += [(m, lui) for m in ms2]
                deja = set(cle(m) for m, p in mots)
                siens = [m for m in releve(r2, PAS_UN_MOT + (nom,)) + plus if cle(m) not in deja]
                mots += [(m, lui) for m in siens]
                fin.append((None, theme + L["sep"] + " ".join(siens)))
            exemple = cle(fin[0][1].split(L["sep"], 1)[1].split()[0])      # premier mot du premier thème
            rows = rows + [(None, L["mot"] % (nom, nom, exemple))] + fin
            vocab.append((moi, table(mots, "")))
        plat.append((nom, titre, rows))
        for theme, t2, ms2, plus, r2 in sous:
            plat.append(("%s (%s)" % (nom, theme), t2, r2))
    index = table(general, "mots generaux (%s)" % code)
    connus = set(m for m, i in index)
    for c in commandes():
        assert c[:8] in connus, "commande sans page d'aide (%s) : %s" % (code, c)
    assert len(plat) <= 127
    return plat, index, vocab


def genere(code, L):
    """-> {fichier: contenu}"""
    plat, index, vocab = structure(code)
    rendus, longues = [], []
    for nom, titre, rows in plat:
        r = render(titre, rows)
        assert len(r) <= MAXL3, "%s (%s) : %d lignes, %d au plus" % (nom, code, len(r), MAXL3)
        if len(r) > MAXL:
            longues.append("%s %d" % (nom, len(r)))
        rendus.append(r)

    # --- README.TXT : notation et renvoi à HELP ---
    readme = render(L["titre"], L["notation"]) + [""] + L["aide"]
    for l in readme:
        assert len(l) <= W, l
    out = {L["readme"]: ("\r\n".join(readme) + "\r\n").encode("ascii")}

    # --- HELP.COM : une chaîne par page, compressées par lots ---
    # Les pages (chacune : lignes + CR LF, puis 0) sont mises bout à bout par
    # lots de LOT octets au plus, chaque lot compressé d'un seul tenant : une
    # page profite des mots des précédentes du lot. help.s décode depuis le
    # début du lot (help_src) jusqu'à la fin de la page demandée (help_ends)
    # dans le tampon qui suit le programme : un lot au plus, quel que soit
    # le mode de l'écran (TPA jusqu'à $9FFF en SPLIT).
    parts = [text(r) for r in rendus]
    lots = [[]]
    for p in parts:
        if lots[-1] and sum(len(q) for q in lots[-1]) + len(p) > LOT:
            lots.append([])
        lots[-1].append(p)
    comp, srcs, offs, ends = b"", [], [], []
    for lot in lots:
        pos = 0
        for p in lot:
            srcs.append(len(comp))
            offs.append(pos)
            pos += len(p)
            ends.append(pos)
        comp += lzhir.compress(b"".join(lot))
    data = b"".join(parts)
    # programme (code, mots, tables : moins de 3 Ko) + données + un lot décodé
    # (une copie peut dépasser de 255 octets) sous $A000
    assert 3072 + len(comp) + LOT + 255 <= 0xA000 - 0x0500, "HELP : trop gros pour la TPA en SPLIT"

    def mots_asm(t, paires):
        for i in range(0, len(paires), 4):
            t.append("        .asc " + ",".join('"%s",%d' % (m, 0x80 + p) for m, p in paires[i:i + 4]))
        t.append("        .byt 0")

    nmots = len(index) + sum(len(v) for p, v in vocab)
    t = ["; helptab.msg : textes de HELP.COM en %s (en %s : progs/msg/%s/helptab.msg)." % (L["langue"], "anglais" if code == "fr" else "français", L["autre"]),
         "; Généré par tools/gen_readme_txt.py — ne pas éditer à la main",
         "; %d pages en %d lots, %d octets de texte, %d compressés ; %d mots" % (len(plat), len(lots), len(data), len(comp), nmots),
         'm_unknown .asc "%s",13,10,13,10,0' % L["inconnu"],
         "; mots généraux : lettres, puis $80 + numéro de la page ; 0 à la fin",
         "help_keys"]
    mots_asm(t, index)
    t.append("; vocabulaires : numéro de la page principale, adresse de ses mots ; $FF à la fin")
    t.append("help_ctx")
    for p, v in vocab:
        t.append("        .byt %d" % p)
        t.append("        .word hk_%d" % p)
    t.append("        .byt $FF")
    for p, v in vocab:
        t.append("hk_%d" % p)
        mots_asm(t, v)
    t.append("; lot de chaque page : début de ses données compressées dans hz_data")
    t.append("help_src")
    t.append("        .word " + ",".join(str(e) for e in srcs))
    t.append("; début de chaque page dans le texte décodé de son lot")
    t.append("help_offs")
    t.append("        .word " + ",".join(str(e) for e in offs))
    t.append("; fin de chaque page (0 final compris) : où le décodage peut s'arrêter")
    t.append("help_ends")
    t.append("        .word " + ",".join(str(e) for e in ends))
    t.append("hz_data")
    for i in range(0, len(comp), 16):
        t.append("        .byt " + ",".join("$%02X" % b for b in comp[i:i + 16]))
    out[L["tab"]] = ("\n".join(t) + "\n").encode("utf-8")
    print("%s : %d pages en %d lots, %d mots, %d octets de texte -> %d compressés ; plus de %d lignes : %s"
          % (code, len(plat), len(lots), nmots, len(data), len(comp), MAXL, ", ".join(longues) or "aucune"))
    return out


def main():
    verifie = "--verifie" in sys.argv[1:]
    perime = []
    for code, L in LANGUES.items():
        for f, contenu in genere(code, L).items():
            chemin = os.path.join(RACINE, f)
            if verifie:
                if not os.path.exists(chemin) or open(chemin, "rb").read() != contenu:
                    perime.append(f)
            else:
                open(chemin, "wb").write(contenu)
    if perime:
        sys.exit("Aide pas a jour (%s) : python3 tools/gen_readme_txt.py" % ", ".join(perime))


if __name__ == "__main__":
    main()
