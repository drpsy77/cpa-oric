#!/usr/bin/env python3
"""Vocabulaire de LOGO en deux langues, à partir d'une seule table.

  gen_logo_voc.py

Chaque primitive a un numéro (son rang dans VOC, à partir de 1 : le futur
token), une routine (p_..., f_...) et ses noms en français et en anglais (le
premier est le nom long, les suivants des abréviations). Produit :

  progs/msg/fr/logovoc.msg, progs/msg/en/logovoc.msg
      tables prims (instructions) et funcs (fonctions) de LOGO.COM, rangées
      par première lettre (ix_build en tire l'index pix), les mots POUR / FIN
      (TO / END), les commandes tapées par les menus (ty_...) et s_charge ;
      inclus par progs/logo.s (build.sh : -I msg/fr ou msg/en)
  progs/lgtr_tab.s
      les deux vocabulaires numérotés, pour le traducteur LOGOTR.COM

Un nom ne doit apparaître qu'une fois par table et par langue (vérifié). En
français, LISTE est à la fois une instruction (montrer une procédure) et une
fonction (faire une liste) ; en anglais : PRINTOUT (PO) et LIST."""
import os
import sys

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# (genre : p instruction, f fonction ; routine ; noms français ; noms anglais)
VOC = [
    ("p", "p_av",      "AVANCE AV",                   "FORWARD FD"),
    ("p", "p_attends", "ATTENDS",                     "WAIT"),
    ("p", "p_attson",  "ATTENDSSON",                  "WAITSOUND"),
    ("p", "p_aide",    "AIDE",                        "HELP"),
    ("p", "p_quitte",  "AUREVOIR QUITTE",             "BYE QUIT"),
    ("p", "p_bc",      "BAISSECRAYON BC",             "PENDOWN PD"),
    ("p", "p_bruitv",  "BRUITV",                      "NOISE"),
    ("p", "p_ct",      "CACHETORTUE CT",              "HIDETURTLE HT"),
    ("p", "p_cercle",  "CERCLE",                      "CIRCLE"),
    ("p", "p_charge",  "CHARGE",                      "LOAD"),
    ("p", "p_cimage",  "CHARGEIMAGE",                 "LOADPIC"),
    ("p", "p_dr",      "DROITE DR",                   "RIGHT RT"),
    ("p", "p_donne",   "DONNE",                       "MAKE"),
    ("p", "p_exec",    "EXECUTE EXEC",                "RUN"),
    ("p", "p_etexte",  "ECRANTEXTE",                  "TEXTSCREEN TS"),
    ("p", "p_edite",   "EDITE",                       "EDIT ED"),
    ("p", "p_emixte",  "ECRANMIXTE",                  "SPLITSCREEN SS"),
    ("p", "p_etiq",    "ETIQUETTE",                   "LABEL"),
    ("p", "p_ecris",   "ECRIS EC",                    "PRINT PR"),
    ("p", "p_env",     "ENVELOPPE",                   "ENVELOPE"),
    ("p", "p_ensemble", "ENSEMBLE",                    "TOGETHER"),
    ("p", "p_fcap",    "FIXECAP",                     "SETHEADING SETH"),
    ("p", "p_fxy",     "FIXEXY",                      "SETXY"),
    ("p", "p_fcoul",   "FIXECOULEUR",                 "SETCOLOR"),
    ("p", "p_fixecur", "FIXECURSEUR",                 "SETCURSOR"),
    ("p", "p_fixecar", "FIXECARECRAN",                "SETCELL"),
    ("p", "p_ga",      "GAUCHE GA",                   "LEFT LT"),
    ("p", "p_gomme",   "GOMME",                       "PENERASE PE"),
    ("p", "p_inv",     "INVERSE",                     "PENREVERSE PX"),
    ("p", "p_lc",      "LEVECRAYON LC",               "PENUP PU"),
    ("p", "p_liste",   "LISTE",                       "PRINTOUT PO"),
    ("p", "p_mt",      "MONTRETORTUE MT",             "SHOWTURTLE ST"),
    ("p", "p_melange", "MELANGE",                     "MIX"),
    ("p", "p_net",     "NETTOIE",                     "CLEAN"),
    ("p", "p_orig",    "ORIGINE",                     "HOME"),
    ("p", "p_oublie",  "OUBLIE",                      "ERASE ER"),
    ("p", "p_oubtout", "OUBLIETOUT",                  "ERALL"),
    ("p", "p_point",   "POINT",                       "DOT"),
    ("p", "p_pave",    "PAVE",                        "FILLRECT"),
    ("p", "p_pour",    "POUR",                        "TO"),
    ("p", "p_rends",   "RENDS",                       "OUTPUT OP"),
    ("p", "p_re",      "RECULE RE",                   "BACK BK"),
    ("p", "p_rect",    "RECTANGLE",                   "RECTANGLE"),
    ("p", "p_repete",  "REPETE",                      "REPEAT"),
    ("p", "p_si",      "SI",                          "IF"),
    ("p", "p_stop",    "STOP",                        "STOP"),
    ("p", "p_sonf",    "SONF",                        "TONE"),
    ("p", "p_son",     "SON",                         "NOTE"),
    ("p", "p_silence", "SILENCE",                     "SILENCE"),
    ("p", "p_sauve",   "SAUVE",                       "SAVE"),
    ("p", "p_simage",  "SAUVEIMAGE",                  "SAVEPIC"),
    ("p", "p_trait",   "TRAIT",                       "LINE"),
    ("p", "p_tape",    "TAPE",                        "TYPE"),
    ("p", "p_titres",  "TITRES",                      "POTS"),
    ("p", "p_ve",      "VIDEECRAN VE",                "CLEARSCREEN CS"),
    ("p", "p_vt",      "VIDETEXTE VT",                "CLEARTEXT CT"),
    ("f", "f_allume",  "ALLUME?",                     "DOT?"),
    ("f", "f_atn",     "ARCTAN",                      "ARCTAN"),
    ("f", "f_ascii",   "ASCII",                       "ASCII"),
    ("f", "f_arrondi", "ARRONDI",                     "ROUND"),
    ("f", "f_abs",     "ABS",                         "ABS"),
    ("f", "f_cap",     "CAP",                         "HEADING"),
    ("f", "f_cos",     "COS",                         "COS"),
    ("f", "f_car",     "CAR",                         "CHAR"),
    ("f", "f_compte",  "COMPTE",                      "COUNT"),
    ("f", "f_curseur", "CURSEUR",                     "CURSOR"),
    ("f", "f_carecr",  "CARECRAN",                    "CELL"),
    ("f", "f_dernier", "DERNIER DER",                 "LAST"),
    ("f", "f_exp",     "EXP",                         "EXP"),
    ("f", "f_ent",     "ENT",                         "INT"),
    ("f", "f_hasard",  "HASARD",                      "RANDOM"),
    ("f", "f_item",    "ITEM",                        "ITEM"),
    ("f", "f_joue",    "JOUE?",                       "PLAYING?"),
    ("f", "f_ln",      "LN",                          "LN"),
    ("f", "f_lisliste", "LISLISTE LL",                 "READLIST RL"),
    ("f", "f_lismot",  "LISMOT",                      "READWORD RW"),
    ("f", "f_liscar",  "LISCAR",                      "READCHAR RC"),
    ("f", "f_liste",   "LISTE",                       "LIST"),
    ("f", "f_listep",  "LISTE?",                      "LIST?"),
    ("f", "f_mot",     "MOT",                         "WORD"),
    ("f", "f_motp",    "MOT?",                        "WORD?"),
    ("f", "f_membrep", "MEMBRE?",                     "MEMBER?"),
    ("f", "f_nombrep", "NOMBRE?",                     "NUMBER?"),
    ("f", "f_phrase",  "PHRASE PH",                   "SENTENCE SE"),
    ("f", "f_premier", "PREMIER PR",                  "FIRST"),
    ("f", "f_quotient", "QUOTIENT",                    "QUOTIENT"),
    ("f", "f_racine",  "RACINE",                      "SQRT"),
    ("f", "f_reste",   "RESTE",                       "REMAINDER"),
    ("f", "f_sin",     "SIN",                         "SIN"),
    ("f", "f_sp",      "SAUFPREMIER SP",              "BUTFIRST BF"),
    ("f", "f_sd",      "SAUFDERNIER SD",              "BUTLAST BL"),
    ("f", "f_touche",  "TOUCHE?",                     "KEY?"),
    ("f", "f_tkey",    "TOUCHE",                      "KEY"),
    ("f", "f_videp",   "VIDE?",                       "EMPTY?"),
    ("f", "f_xcor",    "XCOR",                        "XCOR"),
    ("f", "f_ycor",    "YCOR",                        "YCOR"),
]
# fin de procédure (pas une primitive : reconnue après POUR)
FIN = ("FIN", "END")
# listes d'instructions : les arguments listes de ces primitives sont du code
# (le traducteur y traduit les primitives ; les autres listes sont des données)
CODE = {"p_repete": [2], "p_si": [2, 3], "p_exec": [1], "p_ensemble": [1]}
# commandes tapées par les articles des menus : étiquette, routine, rang du
# nom (0 long, 1 court), fin (" : guillemet, nom à compléter ; CR : exécutée)
TYPES = [("ty_charge", "p_charge", 0, '"'), ("ty_sauve", "p_sauve", 0, '"'),
         ("ty_edite", "p_edite", 0, '"'), ("ty_cimg", "p_cimage", 0, '"'),
         ("ty_simg", "p_simage", 0, '"'), ("ty_titres", "p_titres", 0, "CR"),
         ("ty_oubtout", "p_oubtout", 0, "CR"), ("ty_quitte", "p_quitte", 1, "CR"),
         ("ty_ve", "p_ve", 1, "CR"), ("ty_orig", "p_orig", 0, "CR"), ("ty_ct", "p_ct", 1, "CR"),
         ("ty_mt", "p_mt", 1, "CR"), ("ty_etxt", "p_etexte", 0, "CR"),
         ("ty_emix", "p_emixte", 0, "CR"), ("ty_lc", "p_lc", 1, "CR"), ("ty_aide", "p_aide", 0, "CR")]


def ligne(h):
    return [r for r in VOC if r[1] == h][0]


def noms(r, lang):
    return r[2 + lang].split()


def table(genre, lang):
    """entrées (nom, routine, rang) rangées par première lettre, puis rang dans VOC"""
    ent = []
    for i, r in enumerate(VOC):
        if r[0] == genre:
            for n in noms(r, lang):
                ent.append((n, r[1], i))
    ent.sort(key=lambda e: (e[0][0], e[2]))      # tri stable : abréviations après
    vus = set()
    for n, _, _ in ent:
        if n in vus:
            sys.exit("gen_logo_voc : %s en double" % n)
        vus.add(n)
        if not ("A" <= n[0] <= "Z"):
            sys.exit("gen_logo_voc : %s ne commence pas par une lettre" % n)
    return ent


def msg(lang):
    code, autre = ("fr", "en") if lang == 0 else ("en", "fr")
    out = ["; logovoc.msg : vocabulaire de LOGO.COM en %s (en %s : progs/msg/%s/logovoc.msg)."
           % (("français", "anglais")[lang], ("anglais", "français")[lang], autre),
           "; Généré par tools/gen_logo_voc.py — ne pas éditer à la main.",
           "; Tables rangées par première lettre (ix_build) : nom, 0, adresse de la routine."]
    for genre, lab in (("p", "prims"), ("f", "funcs")):
        out.append(lab)
        for n, h, _ in table(genre, lang):
            out.append('        .asc "%s",0' % n)
            out.append("        .word %s" % h)
        out.append("        .byt 0")
        if genre == "p":
            out.append('w_pour   .asc "%s",0' % noms(ligne("p_pour"), lang)[0])
            out.append('w_fin    .asc "%s",0' % FIN[lang])
    out.append("; commandes tapées par les menus ($18 : efface d'abord la ligne)")
    for lab, h, k, fin in TYPES:
        n = noms(ligne(h), lang)
        n = n[min(k, len(n) - 1)]
        out.append("%-9s .byt $18" % lab)
        if fin == '"':
            out.append('          .asc "%s ",$22,0' % n)
        else:
            out.append('          .asc "%s",13,0' % n)
    out.append('s_charge .asc "%s ",$22,0' % noms(ligne("p_charge"), lang)[0])
    p = os.path.join(RACINE, "progs", "msg", code, "logovoc.msg")
    open(p, "w", encoding="utf-8").write("\n".join(out) + "\n")


def tr_tab():
    """progs/lgtr_tab.s : pour chaque langue, les noms (nom, 0, numéro, rang
    du nom) ; puis, par numéro, le genre et les arguments listes de code"""
    out = ["; lgtr_tab.s : vocabulaires de LOGO numérotés, pour LOGOTR.COM",
           "; Généré par tools/gen_logo_voc.py — ne pas éditer à la main.",
           "TR_N    = %d          ; primitives (numéros 1 à TR_N ; TR_N + 1 : FIN / END)" % len(VOC)]
    for lang, lab in ((0, "tr_fr"), (1, "tr_en")):
        out.append("; %s : nom, 0, numéro, rang du nom (0 : long, 1 : abréviation...)" % lab)
        out.append(lab)
        for i, r in enumerate(VOC):
            for k, n in enumerate(noms(r, lang)):
                out.append('        .asc "%s",0,%d,%d' % (n, i + 1, k))
        out.append('        .asc "%s",0,%d,0' % (FIN[lang], len(VOC) + 1))
        out.append("        .byt 0")
    ids = {r[1]: i + 1 for i, r in enumerate(VOC)}
    out.append("TR_POUR = %d          ; POUR / TO : le mot suivant est un nom de procédure" % ids["p_pour"])
    # un même nom pour une instruction et une fonction (LISTE en français) :
    #   le traducteur choisit d'après la place du mot
    for lang, lab in ((0, "FR"), (1, "EN")):
        pn = {n: r[1] for r in VOC if r[0] == "p" for n in noms(r, lang)}
        fn = {n: r[1] for r in VOC if r[0] == "f" for n in noms(r, lang)}
        dup = sorted(set(pn) & set(fn))
        if len(dup) > 1:
            sys.exit("gen_logo_voc : plus d'un nom à double sens en %s : %s" % (lab, dup))
        p_, f_ = (ids[pn[dup[0]]], ids[fn[dup[0]]]) if dup else (0, 0)
        out.append("TR_%s_DP = %d        ; nom à double sens : numéro de l'instruction (0 : aucun)" % (lab, p_))
        out.append("TR_%s_DF = %d        ;   et de la fonction" % (lab, f_))
    out.append("; par numéro (1 à TR_N) : bit 7 fonction ; bits 0-2 : arguments 1 à 3")
    out.append(";   qui sont des listes d'instructions")
    out.append("tr_kind")
    b = []
    for r in VOC:
        v = 128 if r[0] == "f" else 0
        for a in CODE.get(r[1], []):
            v |= 1 << (a - 1)
        b.append(str(v))
    for i in range(0, len(b), 16):
        out.append("        .byt " + ",".join(b[i:i + 16]))
    open(os.path.join(RACINE, "progs", "lgtr_tab.s"), "w", encoding="utf-8").write("\n".join(out) + "\n")


if __name__ == "__main__":
    if any(len(f) != 3 for f in FIN):   # logo.s : le corps finit à hend - 3
        sys.exit("gen_logo_voc : le mot de fin doit avoir 3 lettres")
    for lang in (0, 1):
        for g in "pf":
            table(g, lang)
        msg(lang)
    tr_tab()
    print("vocabulaire de LOGO : %d primitives, fr et en" % len(VOC))
