#!/usr/bin/env python3
"""Génère l'aide de CP/A à partir d'une seule liste :
  files/readme.txt   README.TXT de la disquette : notation et renvoi à HELP
                     (l'aide-mémoire complet est dans HELP.COM, pour ne pas
                     occuper 10 blocs de 2 Ko une seconde fois)
  progs/help_tab.s   textes de HELP.COM, par rubrique (HELP, HELP EDIT...),
                     compressés en LZSS (tools/lzhir.py, format de
                     archives/lzss-osdk) ; décodés par help.s
Lisible sur l'écran de l'Oric (37 colonnes au plus, sans accents).
Deux colonnes : commande et paramètres | libellé court. Ce qui dépasse
passe à la ligne suivante, décalé."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lzhir

W = 37          # largeur maximale (38 colonnes utiles, la 38e ferait sauter une ligne)
LW = 14         # largeur de la colonne de gauche
RW = W - LW - 2 # à droite de "| "

# (titre, lignes) ; la clé HELP est le premier mot du titre
SECTIONS = [
 ("CP/A 0.9 - AIDE-MEMOIRE", [
  ("afn", "nom, jokers * et ?"),
  ("fic", "nom de fichier, lecteur facultatif (B:NOM.TXT)"),
  ("adr bb", "hexa : 0500 A9"),
  ("[...]", "facultatif"),
 ]),
 ("TOUCHES", [
  ("FUNCT", "menus deroulants"),
  ("CTRL-T", "majuscules oui/non (voyant A ou a au bout de la barre)"),
  ("<- ->", "deplace dans la ligne (on tape en insertion)"),
  ("haut bas", "lignes deja tapees (historique)"),
  ("ESC", "complete un nom de fichier (en debut de ligne : une commande) ; 2 fois : les noms possibles"),
  ("DEL ^D", "efface a gauche / sous"),
  ("^A ^E", "debut / fin de ligne"),
  ("CTRL-X", "efface la ligne"),
  ("CTRL-P", "imprimante oui/non (tout ce qui s'affiche ; voyant P ; aussi menu Systeme)"),
  ("CTRL-C", "redemarrage a chaud"),
  ("RESET", "retour au prompt"),
 ]),
 ("COMMANDES", [
  ("HELP [sujet]", "aide (HELP.COM)"),
  ("VER", "version"),
  ("CLS", "efface l'ecran"),
  ("PAPER n / INK n", "couleur du fond / de l'encre, 0-7 (0 noir 1 rouge 2 vert 3 jaune 4 bleu 5 magenta 6 cyan 7 blanc)"),
  ("PAGE ON/OFF", "pause en fin d'ecran, ou non (aussi menu Ecran, Pagination)"),
  ("B:", "lecteur courant (A: a D:) ; aussi menu Systeme, Lecteur suivant ; un .COM ou .BAT tape sans lecteur est cherche sur le lecteur courant (dans un script : celui du script), puis A:, puis B:, C:, D: deja lus depuis l'allumage (DIR B:...) ; LOCI : tous ceux qui ont une image"),
  ("DIR [afn]", "liste des fichiers"),
  ("DIRS [afn]", "idem, fichiers SYS compris"),
  ("TYPE fic", "affiche un texte"),
  ("ERA afn [/Q]", "efface, apres confirmation (/Q : sans question)"),
  ("REN nouv=anc", "renomme"),
  ("SAVE n fic", "sauve n pages de 0500"),
  ("PUT fic cmd [param]", "lance cmd, copie sa sortie dans fic"),
  ("DO fic [p1..p9]", "lance FIC.BAT ($1..$9 = parametres, ESC arrete)"),
  ("ECHO texte", "affiche le texte"),
  ("PAUSE [texte]", "attend une touche"),
  ("SPLIT", "image + 10 lignes"),
  ("TEXT", "texte seul"),
  ("GCLS", "efface l'image"),
  ("GSAVE fic", "sauve l'image (.IMG)"),
  ("GLOAD fic", "charge l'image"),
  ("NOM [param]", "lance NOM.COM, sinon NOM.BAT"),
  ("(dessin)", "PLOT, LINE... : dans GRAPHER (HELP GRAPHER)"),
 ]),
 ("PROGRAMMES", [
  ("DIRS *.COM", "tous, caches (SYS) compris"),
  ("EDIT [fic]", "editeur de texte"),
  ("HEX fic", "editeur hexadecimal"),
  ("GRAPHER nom [p]", "execute NOM.GRX : dessin, HIRES 240x200 (HELP GRAPHER)"),
  ("GRXASM nom [p]", "traduit NOM.GRX en assembleur (HELP GRAPHER)"),
  ("VOIR nom", "affiche NOM.HIR (plein ecran), .HIZ (compressee) ou .IMG, une touche"),
  ("VOIR nom.ANI [n]", "animation jouee n fois (0 : jusqu'a une touche) ; fleches G D : ligne de dechirure"),
  ("VSYNC", "cale le top 50 Hz sur l'ecran (texte du milieu en entier), jusqu'a l'arret"),
  ("CMDER [d:][afn]", "gestionnaire de fichiers plein ecran : trier, filtrer, marquer, voir, copier... (HELP CMDER)"),
  ("SET afn [opt]", "attributs : RO RW SYS DIR (sans opt : les affiche)"),
  ("LOGO [fic]", "Logo et sa tortue (charge fic.LOG)"),
  ("ASM nom", "NOM.ASM -> NOM.COM et NOM.SYM"),
  ("DEBUG nom [param]", "debogueur"),
  ("COPY src [dst]", "copie, jokers admis : COPY *.COM B:, COPY *.TXT *.BAK, COPY B:*.LOG"),
  ("FORMAT X: [/Q]", "formate X: (A: : un seul lecteur) ; /Q : vide le repertoire"),
  ("DISKCOPY s: d: [opt]", "copie la disquette s: sur d: (A: A: : un seul lecteur) ; /T tout, /V relecture, /S systeme seulement (SYSGEN)"),
  ("STAT [d:][afn]", "taille : enreg., blocs de 2 Ko, octets ; At : R protege, S systeme ; seul : place libre"),
  ("XDO nom [param]", "script appele par un script (lance par le CCP)"),
  ("EXPORT fic [nom]", "copie sur la cle USB du LOCI (HELP USB)"),
  ("IMPORT nom [fic]", "copie depuis la cle USB du LOCI"),
  ("USBDIR [chemin]", "fichiers de la cle USB du LOCI"),
  ("MEM", "carte de la memoire"),
  ("POKE adr bb..", "ecrit en memoire (code a lancer : 0600 et +)"),
  ("GO adr [param]", "lance le code (RTS = retour)"),
  ("GTEST", "demo graphique"),
  ("HELLO [param]", "exemple de .COM"),
 ]),
 ("USB : CLE DU LOCI", [
  ("EXPORT fic [nom]", "fic -> cle (nom : par defaut fic, minuscules gardees)"),
  ("EXPORT afn [dos]", "jokers : chaque fichier sous son nom, dans le dossier dos"),
  ("IMPORT nom [fic]", "cle -> fic (par defaut : nom coupe a 8.3 ; B: seul : sur B:)"),
  ("/T", "(IMPORT) texte : LF seul -> CR LF"),
  ("USBDIR [chemin]", "liste (taille, <REP> : dossier)"),
  ("1:/DOCS/X.TXT", "chemin sur la cle ; sans 1: : la premiere cle"),
  ("0:X.TXT", "memoire interne du LOCI"),
  ("^Z", "retires a l'EXPORT, ajoutes a l'IMPORT"),
  ("X.DSK", "EXPORT refuse (image disque)"),
 ]),
 ("GRAPHER : FICHIERS .GRX", [
  ("GRAPHER nom [p]", "execute NOM.GRX ($1..$9 = p, ESC arrete)"),
  ("nombres", "entiers -32768..32767"),
  ("variables", "A a Z, ou deux car. : PX N1 (sauf IF)"),
  ("parametre", "expression sans espace : X+8 RND(240) (X * 2)"),
  ("operateurs", "- ; * / % ; + - ; = <> < <= > >= ; & |"),
  ("fonctions", "RND(n) ABS(n) POINT(x,y) INKEY SCRN(col,lig) LEN(A$) FOUND"),
  ("V = expr", "affectation (LET V = expr)"),
  ("REPEAT n", "... NEXT"),
  ("FOR V a b [p]", "... NEXT"),
  ("WHILE expr", "... NEXT"),
  ("IF expr", "... [ELSE ...] ENDIF"),
  ("SUB NOM", "... ENDSUB ; CALL NOM ; RETURN"),
  ("PRINT expr", "affiche un nombre (pas en HIRES ; LORES : au curseur)"),
  ("DIM A(n) M$(l,c)", "tableaux d'entiers, d'octets ($) ; nom d'une lettre ; indices 0 a n-1 ; tailles constantes, hors de tout bloc : acces rapides une fois traduit"),
  ("A(i) A(i,j)", "element ; M$(l,c) : un code 0-255"),
  ("A$ M$(l)", "chaine (jusqu'au premier 0) : = < > LEN PRINT"),
  ("A$ = \"texte\"", "affectation ; IF A$ = B$ : comparaison"),
  ("INPUT A$ / V", "saisie d'une chaine / d'un entier"),
  ("FILL A v", "tout le tableau a v"),
  ("GNUM col y n", "nombre dans l'image"),
  ("SAVE A fic", "tableau en texte (.TXT), une ligne par ligne du tableau"),
  ("LOAD A fic", "le relit ; absent : rien ne change, FOUND = 0"),
  ("BSAVE A fic", "tableau en binaire (.DAT) ; BLOAD : le relit"),
  ("BSAVE SCREEN fic", "LORES : l'ecran texte (.SCR) ; BLOAD SCREEN"),
  ("SPRITES n", "LORES : n emplacements de sprites (0 a n-1)"),
  ("SPOOL T [ALT]", "codes libres pour les sprites (tableau d'entiers T, 32-127 ; ALT : jeu secondaire, 32-111)"),
  ("SSHOW k S$ n c l", "sprite n du .SPR (BLOAD S$ NOM.SPR) en col c, lig l, emplacement k ; deplace ; [ALT]"),
  ("SHIDE k", "retire le sprite de l'emplacement k"),
  ("GRXASM nom [p]", "traduit NOM.GRX en NOM.ASM, avec les seules routines utiles de GRX.INC HIRES.INC ARR.INC FIL.INC SPR.INC ANIM.INC (sur le lecteur du .GRX) ; puis ASM NOM -> NOM.COM (avec CPA.INC)"),
  ("GRAPHER nom /A", "la meme chose : passe la main a GRXASM"),
  ("HIRES", "plein ecran 240 x 200, efface"),
  ("SPLIT", "240 x 128, console dessous"),
  ("TEXT", "retour au texte (console)"),
  ("LORES", "ecran texte 40 x 28 au programme, sans console ni menus"),
  ("CLS", "LORES : attribut 16 partout ; sinon la console"),
  ("LOCATE col lig", "curseur (col 0-39, lig 0-27)"),
  ("CHAR col lig c", "octet c dans la case (caractere ou attribut)"),
  ("SPC n [x]", "n fois l'octet x (espace par defaut)"),
  ("TAB n", "avance de n colonnes sans ecrire"),
  ("PRINTV ECHOV SPCV", "comme PRINT ECHO SPC, vers le bas (LORES)"),
  ("PASTE T$(l,c) c l w h", "copie w x h cases de T$ (depuis l,c) a l'ecran en (c,l)"),
  ("GRAB T$(l,c) c l w h", "l'inverse : de l'ecran vers T$"),
  ("SCROLH n [rect [x]]", "glisse de n cases (n > 0 : a droite) ; rect = c1 l1 c2 l2 ; x : cases liberees"),
  ("SCROLV n [rect [x]]", "idem en hauteur (n > 0 : vers le bas)"),
  ("ROTH n [rect]", "rotation : ce qui sort rentre de l'autre cote ; ROTV : en hauteur"),
  ("ECHO \"texte\"", "LORES : au curseur, tel quel ; ECHO seul : ligne suivante ; rien apres la colonne 39"),
  ("GCLS", "efface l'image"),
  ("PEN m", "0 efface 1 trace 2 inv."),
  ("PLOT x y", "point (x 0-239, y 0-199)"),
  ("LINE x1 y1 x2 y2", "ligne"),
  ("BOX x1 y1 x2 y2", "rectangle (FBOX : plein)"),
  ("CIRCLE x y r", "cercle"),
  ("GTEXT col y texte", "texte dans l'image (col 0-39)"),
  ("ATTR col y1 y2 v", "attribut : encre 0-7, papier 16-23"),
  ("GLOAD fic", ".HIR ou .HIZ (HIRES), .IMG (SPLIT)"),
  ("ANIM fic [n]", "animation .ANI en HIRES, n fois (0 : jusqu'a une touche)"),
  ("GSAVE fic", "idem, selon le mode"),
  ("WAIT", "attend une touche"),
  ("GET V", "attend une touche, son code dans V"),
  ("DELAY n", "attend n/50 s"),
  ("ECHO texte", "affiche (pas en HIRES)"),
  ("END", "fin ; HIRES et LORES : retour a la console (WAIT avant pour attendre)"),
  ("; texte", "commentaire"),
 ]),
 ("EDIT", [
  ("fleches", "deplacement"),
  ("^A ^E", "debut / fin de ligne"),
  ("^R ^C", "page prec. / suiv."),
  ("^Q ^Z", "debut / fin du texte"),
  ("DEL ^D", "efface avant / sous"),
  ("^Y", "efface le paragraphe"),
  ("^O", "insere / remplace"),
  ("^F ^G", "cherche / suivant"),
  ("^S", "enregistre"),
  ("^L", "insere un fichier au curseur"),
  ("^P", "imprime le texte, mis en page (ESC arrete)"),
  ("^N", "paragraphe trop long suivant"),
  ("C 127!", "(ligne d'etat) position dans le paragraphe ; ! : plus long que le maxi"),
  ("EDIT.CFG", "par fichier : nom maxi [MOTS|CAR] [largeur impr.], ex. *.LOG 126 CAR 80"),
  ("FUNCT", "menus Fichier (dont Inserer, Imprimer), Edition, Chercher, Options"),
  ("Retour", "(lance par EDITE de LOGO) enregistre et revient"),
 ]),
 ("CMDER : FICHIERS PLEIN ECRAN", [
  ("CMDER [d:][afn]", "fichiers de d:, filtre afn (CMDER B:*.COM)"),
  ("CMDER A: B:", "deux colonnes (A: A: refuse)"),
  ("^X ^W ^Z", "autre colonne / echanger / plein ecran"),
  ("CMDER USB:[ch]", "cle USB du LOCI (A: USB: : deux colonnes) ; RETURN : entre dans un dossier, .. remonte ; copie seulement"),
  ("/T", "(copie depuis la cle) LF seul -> CR LF ; menu Copier texte"),
  ("haut bas", "fichier precedent / suivant"),
  ("<- ->", "page precedente / suivante"),
  ("< >", "premier / dernier fichier"),
  ("A a Z", "fichier suivant qui commence par la lettre"),
  ("ESP", "marque / ote la marque"),
  ("+ -", "marque / ote selon un modele (*.COM)"),
  ("*", "inverse les marques"),
  ("1 2 3 4", "tri : disque, nom, type, taille ; 2 fois : ordre inverse"),
  ("/", "filtre (B:*.TXT : autre lecteur)"),
  ("RETURN", "voir le texte"),
  ("^C ^D", "copier / deplacer vers B: ou NOM.EXT ; A: (lecteur de la liste) : un seul lecteur, disquettes echangees"),
  ("^N", "renommer"),
  ("DEL", "effacer (confirmation)"),
  ("^A", "attributs R (protege) S (systeme)"),
  ("? ^E", "taille exacte : du fichier / de tous"),
  ("^L ^R", "autre lecteur / relire (disquette changee)"),
  ("FUNCT", "menus Fichier (Imprimer liste), Marque, Trier, Vue (Absents autre : fichiers absents de l'autre colonne ou differents)"),
  ("ESC", "quitter"),
  ("cibles", "les fichiers marques, sinon celui du curseur"),
 ]),
 ("HEX", [
  ("fleches RET", "deplacement"),
  ("^R ^C", "page prec. / suiv."),
  ("^Q ^Z", "debut / fin"),
  ("^A", "aller a l'adresse"),
  ("^F ^G", "cherche texte ou #hexa / suivant"),
  ("^O", "mode HEX / ASCII"),
  ("^S", "enregistre"),
  ("ESC", "quitte"),
 ]),
 ("LOGO", [
  ("AV n  RE n", "avance / recule (n decimal admis)"),
  ("DR n  GA n", "droite / gauche (degres, 0.5 admis)"),
  ("LC  BC", "leve / baisse stylo"),
  ("CT  MT", "cache / montre"),
  ("VE  ORIGINE", "vide ecran / centre"),
  ("POINT x y", "un point (coordonnees de la tortue, qui ne bouge pas)"),
  ("TRAIT x y x y", "un trait ; RECTANGLE, PAVE (plein) : coins opposes"),
  ("CERCLE r", "autour de la tortue (r 0-127)"),
  ("ETIQUETTE x", "ecrit x dans l'image a la tortue"),
  ("FIXECOULEUR v", "encre 0-7 ou papier 16-23 de l'image"),
  ("ALLUME? x y", "1 si le point est allume"),
  ("ECRANTEXTE", "tout en texte"),
  ("ECRANMIXTE", "retour a l'image"),
  ("VT", "efface le texte (VIDETEXTE)"),
  ("TAPE x", "ecrit, sans aller a la ligne"),
  ("FIXECURSEUR c l", "curseur colonne 0-39, ligne 0-27 (ecran entier)"),
  ("FIXECARECRAN c l n", "code n dans la case (attributs 0-31)"),
  ("REPETE n [..]", "repete la liste"),
  ("SI c [..] [..]", "condition"),
  ("POUR NOM :A ... FIN", "definit une procedure"),
  ("RENDS x", "la procedure rend x"),
  ("EC x", "ecrit"),
  ("SAUVE \"N", "procedures -> N.LOG"),
  ("CHARGE \"N", "charge N.LOG"),
  ("EDITE \"N", "N.LOG dans EDIT, puis Retour"),
  ("SAUVEIMAGE \"N", "dessin -> N.IMG"),
  ("CHARGEIMAGE \"N", "charge N.IMG"),
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
  ("LISLISTE", "lit une ligne -> liste (LL)"),
  ("LISMOT", "lit une ligne -> mot"),
  ("LISCAR", "attend une touche -> caractere"),
  ("ASCII x  CAR n", "code d'un caractere / caractere"),
  ("TOUCHE?", "1 si une touche attend, 0 sinon"),
  ("TOUCHE", "touche enfoncee, sans delai (jeux) ; mot vide si aucune"),
  ("CURSEUR", "[colonne ligne] du curseur"),
  ("CARECRAN c l", "code de la case"),
  ("SON v n vol d", "note n (37 = do, 0 = rien) sur la voix v (0-2), volume 0-15 (16 = enveloppe), d/50 s (0 : sans fin)"),
  ("SONF v p vol d", "son de periode p (0-4095)"),
  ("BRUITV v p vol d", "bruit de periode p (0-31)"),
  ("ENVELOPPE f p", "forme 0-15, periode 0-65535"),
  ("MELANGE v s b", "son et bruit de la voix (1 / 0)"),
  ("ENSEMBLE [..]", "les voix de la liste partent ensemble"),
  ("ATTENDSSON v", "attend la fin (255 : toutes)"),
  ("JOUE? v", "1 si la voix joue encore"),
  ("SILENCE", "coupe le son"),
  ("AIDE", "liste complete"),
  ("QUITTE", "retour a CP/A"),
 ]),
 ("ASM : SYNTAXE", [
  ("etiq", "en colonne 1"),
  ("NOM = expr", "constante"),
  ("*= adr", "adresse (0500)"),
  (".byt .asc", "octets, \"chaines\""),
  (".word", "mots 16 bits"),
  (".dsb n[,v]", "n octets"),
  (".(  .)", "bloc, etiquettes locales"),
  ("#include \"f\"", "inclusion"),
  ("$ % \"c\" *", "hexa, binaire, car., ici"),
  ("< >", "octet bas / haut"),
 ]),
 ("MEMOIRE", [
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
 ]),
 ("DEBUG", [
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

lines = []
for title, rows in SECTIONS:
    if lines:
        lines.append("")
    lines.append(title)
    lines.append("-" * len(title))
    for left, right in rows:
        rparts = wrap(right, RW, RW - 2)
        if len(left) > LW - 1:                      # commande trop longue : seule
            lines.append(left)
            first = " " * LW + "| " + rparts[0]
        else:
            first = left.ljust(LW) + "| " + rparts[0]
        lines.append(first)
        for p in rparts[1:]:                    # suite du libellé, décalée
            lines.append(" " * LW + "|   " + p)

def render(title, rows):
    out = [title, "-" * len(title)]
    for left, right in rows:
        rparts = wrap(right, RW, RW - 2)
        if len(left) > LW - 1:
            out.append(left)
            out.append(" " * LW + "| " + rparts[0])
        else:
            out.append(left.ljust(LW) + "| " + rparts[0])
        for q in rparts[1:]:
            out.append(" " * LW + "|   " + q)
    for l in out:
        assert len(l) <= W, l
    return out

for l in lines:
    assert len(l) <= W, l

byname = {t.split()[0].replace(":", ""): (t, r) for t, r in SECTIONS}
topics = ["TOUCHES", "PROGRAMMES", "EDIT", "HEX", "LOGO", "ASM", "DEBUG", "MEMOIRE", "USB", "GRAPHER", "CMDER"]
sujets = ["  " + " ".join(topics[:4]), "  " + " ".join(topics[4:8]), "  " + " ".join(topics[8:]),
          "  (4 lettres suffisent)"]

# --- README.TXT : notation et renvoi à HELP ---------------------------
readme = render(*SECTIONS[0]) + ["", "Aide : HELP (commandes internes)", "et HELP suivi d'un sujet :"] + sujets
for l in readme:
    assert len(l) <= W, l
dest = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "files", "readme.txt")
open(dest, "wb").write(("\r\n".join(readme) + "\r\n").encode("ascii"))
print(len(readme), "lignes dans README.TXT")

# --- HELP.COM : une chaîne par rubrique, le tout compressé -------------
# Les rubriques sont mises bout à bout (chacune : lignes + CR LF, puis 0)
# et compressées d'un seul tenant : une rubrique profite des mots des
# précédentes. help.s décode depuis le début jusqu'à la fin de la rubrique
# demandée (help_ends) dans le tampon qui suit le programme.
def text(lines):
    return "".join(l + "\r\n" for l in lines).encode("ascii") + b"\0"

default = render(*byname["COMMANDES"]) + ["", "Autres sujets : HELP suivi de"] + sujets
parts = [text(default)] + [text(render(*byname[t])) for t in topics]
data = b"".join(parts)
comp = lzhir.compress(data)
ends, pos = [], 0
for p in parts:
    pos += len(p)
    ends.append(pos)

out = ["; Généré par tools/gen_readme_txt.py — ne pas éditer à la main",
       "; %d octets de texte, %d compressés" % (len(data), len(comp)),
       "help_keys"]
for t in topics:
    out.append('        .asc "%s",0' % t[:4])     # 4 premières lettres suffisent
out.append("        .byt 0")
out.append("; début de chaque rubrique dans le texte décodé (h_default, puis les sujets)")
out.append("help_offs")
out.append("        .word " + ",".join(str(e) for e in [0] + ends[:-1]))
out.append("; fin de chaque rubrique (0 final compris) : où le décodage peut s'arrêter")
out.append("help_ends")
out.append("        .word " + ",".join(str(e) for e in ends))
out.append("hz_data")
for i in range(0, len(comp), 16):
    out.append("        .byt " + ",".join("$%02X" % b for b in comp[i:i + 16]))
dest2 = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "progs", "help_tab.s")
open(dest2, "w").write("\n".join(out) + "\n")
print("HELP : %d octets de texte -> %d compressés" % (len(data), len(comp)))
