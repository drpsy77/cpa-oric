#!/usr/bin/env python3
"""Génère l'aide de CP/A à partir d'une seule liste :
  files/readme.txt   aide-mémoire complet (README.TXT sur la disquette)
  progs/help_tab.s   textes de HELP.COM, par rubrique (HELP, HELP EDIT...)
Lisible sur l'écran de l'Oric (37 colonnes au plus, sans accents).
Deux colonnes : commande et paramètres | libellé court. Ce qui dépasse
passe à la ligne suivante, décalé."""
import os

W = 37          # largeur maximale (38 colonnes utiles, la 38e ferait sauter une ligne)
LW = 14         # largeur de la colonne de gauche
RW = W - LW - 2 # à droite de "| "

# (titre, lignes) ; la clé HELP est le premier mot du titre
SECTIONS = [
 ("CP/A 0.9 - AIDE-MEMOIRE", [
  ("afn", "nom, jokers * et ?"),
  ("fic", "nom de fichier"),
  ("adr bb", "hexa : 0500 A9"),
  ("[...]", "facultatif"),
 ]),
 ("TOUCHES", [
  ("FUNCT", "menus deroulants"),
  ("CTRL-T", "majuscules oui/non"),
  ("CTRL-X", "efface la ligne"),
  ("CTRL-C", "redemarrage a chaud"),
  ("DEL", "efface a gauche"),
  ("RESET", "retour au prompt"),
 ]),
 ("COMMANDES", [
  ("HELP [sujet]", "aide (HELP.COM)"),
  ("VER", "version"),
  ("CLS", "efface l'ecran"),
  ("DIR [afn]", "liste des fichiers"),
  ("DIRS [afn]", "idem, fichiers SYS compris"),
  ("TYPE fic", "affiche un texte"),
  ("ERA afn", "efface des fichiers"),
  ("REN nouv=anc", "renomme"),
  ("SAVE n fic", "sauve n pages de 0500"),
  ("PUT fic cmd [param]", "lance cmd, copie sa sortie dans fic"),
  ("DO fic [p1..p9]", "lance FIC.BAT ($1..$9 = parametres, ESC arrete)"),
  ("ECHO texte", "affiche le texte"),
  ("PAUSE [texte]", "attend une touche"),
  ("SPLIT", "image + 11 lignes"),
  ("TEXT", "texte seul"),
  ("GCLS", "efface l'image"),
  ("PEN m", "0 efface 1 trace 2 inv."),
  ("PLOT x y", "point (x 0-239, y 0-127)"),
  ("LINE x1 y1 x2 y2", "ligne"),
  ("BOX x1 y1 x2 y2", "rectangle"),
  ("FBOX x1 y1 x2 y2", "rectangle plein"),
  ("CIRCLE x y r", "cercle"),
  ("GTEXT col y texte", "texte dans l'image (col 0-39)"),
  ("ATTR col y1 y2 v", "attribut : encre 0-7, papier 16-23"),
  ("POINT x y", "affiche 1 si allume"),
  ("GSAVE fic", "sauve l'image (.IMG)"),
  ("GLOAD fic", "charge l'image"),
  ("NOM [param]", "lance NOM.COM"),
 ]),
 ("PROGRAMMES", [
  ("EDIT [fic]", "editeur de texte"),
  ("HEX fic", "editeur hexadecimal"),
  ("SET afn [opt]", "attributs : RO RW SYS DIR (sans opt : les affiche)"),
  ("LOGO", "Logo et sa tortue"),
  ("ASM nom", "NOM.ASM -> NOM.COM et NOM.SYM"),
  ("DEBUG nom [param]", "debogueur"),
  ("COPY src dst", "copie un fichier"),
  ("GTEST", "demo graphique"),
  ("HELLO [param]", "exemple de .COM"),
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
  ("FUNCT", "menus Fichier (dont Inserer), Edition, Chercher, Options"),
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
  ("AV n  RE n", "avance / recule"),
  ("DR n  GA n", "droite / gauche"),
  ("LC  BC", "leve / baisse stylo"),
  ("CT  MT", "cache / montre"),
  ("VE  ORIGINE", "vide ecran / centre"),
  ("REPETE n [..]", "repete la liste"),
  ("SI c [..] [..]", "condition"),
  ("POUR NOM :A ... FIN", "definit une procedure"),
  ("EC x", "ecrit"),
  ("SAUVE \"N", "procedures -> N.LOG"),
  ("CHARGE \"N", "charge N.LOG"),
  ("SAUVEIMAGE \"N", "dessin -> N.IMG"),
  ("CHARGEIMAGE \"N", "charge N.IMG"),
  ("NOTE n d", "joue la note n (37 = do) pendant d/50 s"),
  ("BRUIT d", "bruit pendant d/50 s"),
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
dest = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "files", "readme.txt")
open(dest, "wb").write(("\r\n".join(lines) + "\r\n").encode("ascii"))
print(len(lines), "lignes")

# --- HELP.COM : une chaîne par rubrique -------------------------------
def asm_str(lines):
    res = []
    for l in lines:
        esc = l.replace('"', '",34,"')
        res.append('        .asc "%s",13,10' % esc)
    res.append('        .byt 0')
    return "\n".join(res).replace('.asc "",34,"', '.asc 34,"').replace(',""', '')

byname = {t.split()[0].replace(":", ""): (t, r) for t, r in SECTIONS}
topics = ["TOUCHES", "PROGRAMMES", "EDIT", "HEX", "LOGO", "ASM", "DEBUG", "MEMOIRE"]
default = render(*byname["COMMANDES"]) + ["", "Autres sujets : HELP suivi de",
          "  " + " ".join(topics[:4]), "  " + " ".join(topics[4:]),
          "  (4 lettres suffisent)"]
out = ["; Généré par tools/gen_readme_txt.py — ne pas éditer à la main",
       "help_keys"]
for t in topics:
    out.append('        .asc "%s",0' % t[:4])     # 4 premières lettres suffisent
out.append("        .byt 0")
out.append("help_ptrs")
out.append("        .word h_default," + ",".join("h_%d" % i for i in range(len(topics))))
out.append("h_default")
out.append(asm_str(default))
for i, t in enumerate(topics):
    out.append("h_%d" % i)
    out.append(asm_str(render(*byname[t])))
dest2 = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "progs", "help_tab.s")
open(dest2, "w").write("\n".join(out) + "\n")
