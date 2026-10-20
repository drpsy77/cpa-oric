#!/usr/bin/env python3
"""Mesures du projet CP/A pour docs/points-de-fonction.md.

  python3 tools/pf_mesure.py            affiche les mesures et la synthèse
  python3 tools/pf_mesure.py --ecrire   les recopie dans docs/points-de-fonction.md
                                        (entre les marques <!-- mesures --> et
                                        <!-- synthese -->)
  python3 tools/pf_mesure.py --git-log F   historique pris dans F
                                        (sortie de git log --name-only
                                        --format='@%h %ad' --date=short)

Ce que le script fait seul :
  - lignes de code, de commentaires, vides, et lignes générées (tables, police,
    textes de HELP) par composant, d'après la répartition COMPOSANTS ;
  - octets produits (build/progs/*.COM, build/cpa_sys.sym, build/boot.bin :
    lancer ./build.sh avant) ;
  - lignes de documentation par composant (docs/*.md, sections de manuel.md,
    rubriques de l'aide de HELP.COM) ;
  - commits qui touchent chaque composant ;
  - réutilisation : lignes assemblées dans les .COM (bibliothèques comprises)
    par rapport aux lignes écrites ;
  - comparaison avec CP/M 2.2 (§ 11), comptée avec les mêmes règles ;
  - points de fonction : relit les tableaux détaillés du document (lignes dont
    la première case est un identifiant comme SYS.T01 ou LOGO.A03), vérifie la
    complexité d'après les RET/FTR et DET (matrices IFPUG 4.3) et le nombre de
    points, puis fait les totaux. Une erreur arrête le script (code 1).
"""
import fnmatch
import os
import re
import subprocess
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOC = os.path.join(RACINE, "docs", "points-de-fonction.md")

# --- répartition des fichiers ------------------------------------------------
# (composant, motifs) ; le premier motif qui correspond l'emporte.
SYS_COM = "type era ren set stat copy format diskcopy xdo help help_tab mem poke go vsync".split()
COMPOSANTS = [
    ("SYS",  ["src/*", "boot/*", "progs/cpa.inc"] + ["progs/%s.s" % n for n in SYS_COM]
             + ["progs/msg/*/%s.msg" % n for n in SYS_COM]),
    ("EDIT", ["progs/edit.s", "progs/edit_tab.s", "progs/msg/*/edit.msg"]),
    ("GRA",  ["progs/grapher.s", "progs/grxasm.s", "progs/grxd_inc.s", "progs/grxc_inc.s",
              "progs/grx.inc", "progs/arr.inc", "progs/fil.inc", "progs/spr.inc"]),
    ("LOGO", ["progs/logo.s", "progs/logo_tab.s", "progs/fp_inc.s", "progs/ltxt_inc.s"]),
    ("CMD",  ["progs/cmder.s"]),
    ("HEX",  ["progs/hex.s", "progs/msg/*/hex.msg"]),
    ("VOIR", ["progs/voir.s", "progs/anim.inc", "progs/hires.inc", "progs/msg/*/voir.msg"]),
    ("USB",  ["progs/export.s", "progs/import.s", "progs/usbdir.s", "progs/loci_inc.s",
              "progs/msg/*/export.msg", "progs/msg/*/import.msg", "progs/msg/*/usbdir.msg",
              "progs/msg/*/loci.msg"]),
    ("ASM",  ["progs/asm.s", "progs/asm_tab.s", "progs/msg/*/asm.msg"]),
    ("DBG",  ["progs/debug.s", "progs/msg/*/debug.msg"]),
    ("EX",   ["progs/hello.s", "progs/gtest.s", "files/*.grx", "files/*.log", "files/*.bat",
              "files/*.spr", "files/anim/*"]),
    ("OUT",  ["build.sh", "tools/*.py", "tools/*.sh", "tools/*.patch", "tools/*.s",
              "tools/grapher_tests/*.grx", "tools/logo_tests/*.log"]),
]
NOMS = {"SYS": "Système et commandes", "EDIT": "EDIT", "GRA": "GRAPHER + GRXASM",
        "LOGO": "LOGO", "CMD": "CMDER", "HEX": "HEX", "VOIR": "VOIR", "USB": "USB",
        "ASM": "ASM", "DBG": "DEBUG", "EX": "Exemples", "OUT": "Outillage PC",
        "TRA": "Transverse (projet)", "EN": "Traduction anglaise (docs/en)",
        "CPM": "CP/M 2.2 : système et utilitaires", "CPMED": "CP/M 2.2 : ED",
        "CPMASM": "CP/M 2.2 : ASM, LOAD", "CPMDDT": "CP/M 2.2 : DDT"}
# comparaison avec CP/M 2.2 (§ 11 du document) : domaine, composants CP/A, composants CP/M
COMPARAISON = [("Système, commandes, utilitaires de fichiers", ["SYS"], ["CPM"]),
               ("Éditeur (EDIT / ED)", ["EDIT"], ["CPMED"]),
               ("Assembleur (ASM / ASM et LOAD)", ["ASM"], ["CPMASM"]),
               ("Débogueur (DEBUG / DDT)", ["DBG"], ["CPMDDT"])]
GROUPES = [("Système", ["SYS"]),
           ("Applications", ["EDIT", "GRA", "LOGO", "CMD", "HEX", "VOIR", "USB", "ASM", "DBG"]),
           ("Exemples", ["EX"]), ("Outillage", ["OUT"])]
ORDRE = [c for _, l in GROUPES for c in l]

# programmes .COM de chaque composant (octets)
COMS = {"SYS": [n.upper() for n in SYS_COM if n != "help_tab"], "EDIT": ["EDIT"],
        "GRA": ["GRAPHER", "GRXASM"], "LOGO": ["LOGO"], "CMD": ["CMDER"], "HEX": ["HEX"],
        "VOIR": ["VOIR"], "USB": ["EXPORT", "IMPORT", "USBDIR"], "ASM": ["ASM"],
        "DBG": ["DEBUG"], "EX": ["HELLO", "GTEST"]}

# documentation : fichier -> composant ; manuel.md est découpé par section (## ...)
DOCS = {"architecture.md": "SYS", "systeme.md": "SYS", "memoire-pages-2-3.md": "SYS",
        "projet-rom.md": "SYS", "logo.md": "LOGO", "grapher.md": "GRA", "cmder.md": "CMD",
        "atelier.md": "OUT", "etat.md": "TRA", "essais-materiel.md": "TRA",
        "oric-basic.md": "TRA", "loci-modem-wifi.md": "TRA", "points-de-fonction.md": "TRA",
        "../README.md": "TRA", "../README.fr.md": "TRA",
        "en/manuel.md": "EN", "en/logo.md": "EN", "en/grapher.md": "EN", "en/cmder.md": "EN", "../CLAUDE.md": "TRA", "../tools/LISEZMOI-mac.txt": "OUT"}
MANUEL = [("Échange de fichiers", "USB"), ("HIRES plein", "VOIR"), ("L'éditeur de texte", "EDIT"),
          ("L'éditeur hexa", "HEX"), ("L'assembleur", "ASM"), ("Le débogueur", "DBG"),
          ("Outils", "OUT")]          # les autres sections : SYS
AIDE = {"CP/A": "SYS", "TOUCHES": "SYS", "COMMANDES": "SYS", "PROGRAMMES": "SYS",
        "MEMOIRE": "SYS", "USB": "USB", "GRAPHER": "GRA", "EDIT": "EDIT", "CMDER": "CMD",
        "HEX": "HEX", "LOGO": "LOGO", "ASM": "ASM", "DEBUG": "DBG"}

POIDS = {"ILF": (7, 10, 15), "EIF": (5, 7, 10), "EI": (3, 4, 6), "EO": (4, 5, 7), "EQ": (3, 4, 6)}
FACTEUR = 1.05    # facteur d'ajustement, § 9 du document
CPLX = "FMÉ"    # faible, moyenne, élevée


def complexite(t, r, d):
    """Matrices IFPUG 4.3 : r = RET (données) ou FTR (transactions), d = DET."""
    if t in ("ILF", "EIF"):
        lig = 0 if r <= 1 else (1 if r <= 5 else 2)
        col = 0 if d <= 19 else (1 if d <= 50 else 2)
    elif t == "EI":
        lig = 0 if r <= 1 else (1 if r == 2 else 2)
        col = 0 if d <= 4 else (1 if d <= 15 else 2)
    else:   # EO, EQ
        lig = 0 if r <= 1 else (1 if r <= 3 else 2)
        col = 0 if d <= 5 else (1 if d <= 19 else 2)
    m = [[0, 0, 1], [0, 1, 2], [1, 2, 2]]
    return m[lig][col]


def composant(rel):
    for c, motifs in COMPOSANTS:
        for m in motifs:
            # un * ne traverse pas les dossiers
            if fnmatch.fnmatchcase(rel, m) and rel.count("/") == m.count("/"):
                return c
    return None


def fichiers():
    vus = []
    for d, sous, noms in os.walk(RACINE):
        rd = os.path.relpath(d, RACINE)
        sous[:] = [s for s in sous if not s.startswith(".") and s not in ("build", "__pycache__")
                   and os.path.join(rd, s).replace("./", "") not in
                   ("tools/oricutron", "tools/clk-mac", "tools/clk", "tools/pylib", "archives")]
        for n in noms:
            rel = os.path.normpath(os.path.join(rd, n)).replace("\\", "/")
            c = composant(rel)
            if c:
                vus.append((c, rel))
    return sorted(vus)


BINAIRES = (".ani", ".hiz", ".hir", ".gif", ".png", ".spr")


def compter(rel):
    """(code, commentaires, vides, générées, octets si binaire)"""
    p = os.path.join(RACINE, rel)
    if rel.lower().endswith(BINAIRES):
        return 0, 0, 0, 0, os.path.getsize(p)
    with open(p, encoding="utf-8", errors="replace") as f:
        lignes = f.read().splitlines()
    if lignes and ("Généré" in lignes[0] or (len(lignes) > 1 and "Généré" in lignes[1])):
        return 0, 0, 0, len(lignes), 0
    code = com = vide = 0
    py = rel.endswith((".py", ".sh")) or rel == "build.sh"
    doc = False
    for l in lignes:
        s = l.strip()
        if not s:
            vide += 1
        elif py:
            if s.startswith(('"""', "'''")):
                com += 1
                if not (len(s) > 3 and s.endswith(s[:3])):
                    doc = not doc
            elif doc:
                com += 1
                if s.endswith(('"""', "'''")):
                    doc = False
            elif s.startswith("#"):
                com += 1
            else:
                code += 1
        elif rel.endswith(".patch"):
            code += 1
        elif s.startswith(";") and not rel.endswith(".log"):
            com += 1
        else:
            code += 1
    return code, com, vide, 0, 0


def octets():
    o = {}
    b = os.path.join(RACINE, "build")
    for c, l in COMS.items():
        for n in l:
            p = os.path.join(b, "progs", n + ".COM")
            o[c] = o.get(c, 0) + (os.path.getsize(p) if os.path.exists(p) else 0)
    sym = {}
    p = os.path.join(b, "cpa_sys.sym")
    if os.path.exists(p):
        for l in open(p):
            a = l.split()
            if len(a) == 2:
                sym[a[1]] = int(a[0], 16)
    res = {}
    if "rom_end" in sym:
        res["code"] = sym["rom_end"] - 0xC000
        res["ff"] = sym.get("ff_end", 0xFF00) - 0xFF00
        o["SYS"] = o.get("SYS", 0) + res["code"] + res["ff"]
    p = os.path.join(b, "boot.bin")
    if os.path.exists(p):
        res["boot"] = os.path.getsize(p)
        o["SYS"] = o.get("SYS", 0) + res["boot"]
    return o, res


def documentation():
    lig = {}
    d = os.path.join(RACINE, "docs")

    def add(c, n):
        lig[c] = lig.get(c, 0) + n
    for n, c in DOCS.items():
        p = os.path.normpath(os.path.join(d, n))
        if os.path.exists(p):
            add(c, sum(1 for l in open(p, encoding="utf-8") if l.strip()))
    cur = "SYS"
    for l in open(os.path.join(d, "manuel.md"), encoding="utf-8"):
        if l.startswith("## "):
            cur = next((c for t, c in MANUEL if l[3:].startswith(t)), "SYS")
        if l.strip():
            add(cur, 1)
    aide = {}
    cur = None
    for l in open(os.path.join(RACINE, "tools", "gen_readme_txt.py"), encoding="utf-8"):
        m = re.match(r' \("([^"]+)", \[', l)
        if m:
            mot = m.group(1).split()[0].rstrip(":")
            cur = AIDE.get(mot, "SYS")
        elif l.startswith(" ]),"):
            cur = None
        elif cur and l.startswith("  (\""):
            aide[cur] = aide.get(cur, 0) + 1
        elif l.startswith("]"):
            break
    return lig, aide


def commits(journal):
    if journal:
        texte = open(journal, encoding="utf-8").read()
    else:
        try:
            texte = subprocess.run(["git", "log", "--name-only", "--format=@%h %ad", "--date=short"],
                                   cwd=RACINE, capture_output=True, text=True, check=True).stdout
        except Exception:
            return None, None, None
    par, tous, dates = {}, 0, []
    cur = None
    for l in texte.splitlines() + ["@fin"]:
        if l.startswith("@"):
            if cur is not None:
                for c in cur:
                    par[c] = par.get(c, 0) + 1
            if l != "@fin":
                tous += 1
                dates.append(l.split()[1])
            cur = set()
        elif l.strip() and cur is not None:
            c = composant(l.strip())
            if c is None and l.startswith("docs/"):
                n = l[5:]
                c = DOCS.get(n, "SYS" if n == "manuel.md" else None)
            if c:
                cur.add(c)
    return par, tous, (min(dates), max(dates)) if dates else None


def reutilisation():
    """lignes assemblées dans les .COM (inclusions comprises) / lignes écrites"""
    pr = os.path.join(RACINE, "progs")
    taille = {}
    for n in os.listdir(pr):
        if n.endswith((".s", ".inc")):
            taille[n] = sum(1 for l in open(os.path.join(pr, n), encoding="utf-8", errors="replace")
                            if l.strip() and not l.strip().startswith(";"))

    def incl(n, vus):
        if n in vus or n not in taille:
            return 0
        vus.add(n)
        t = taille[n]
        for l in open(os.path.join(pr, n), encoding="utf-8", errors="replace"):
            m = re.match(r'\s*#include\s+"([^"]+)"', l)
            if m:
                t += incl(m.group(1).lower(), vus)
        return t
    livres = sum(incl(n, set()) for n in taille if n.endswith(".s") and not n.endswith(("_tab.s", "_inc.s")))
    return livres, sum(taille.values())


def points_de_fonction():
    """relit les tableaux détaillés du document ; rend (pf, algo, nb, erreurs)"""
    pf, algo, nb, err = {}, {}, {}, []
    if not os.path.exists(DOC):
        return pf, algo, nb, ["document absent"]
    ids = set()
    for no, l in enumerate(open(DOC, encoding="utf-8"), 1):
        if not l.startswith("| "):
            continue
        cases = [c.strip() for c in l.strip().strip("|").split("|")]
        m = re.match(r"^([A-Z]+)\.([DTA])(\d+)$", cases[0])
        if not m:
            continue
        comp, genre = m.group(1), m.group(2)
        if comp not in NOMS:
            err.append("ligne %d : composant inconnu %s" % (no, comp))
            continue
        if cases[0] in ids:
            err.append("ligne %d : identifiant en double %s" % (no, cases[0]))
        ids.add(cases[0])
        try:
            if genre == "A":
                p = int(cases[-1])
                if p not in (1, 3, 5):
                    err.append("ligne %d : %s, points %d (1, 3 ou 5)" % (no, cases[0], p))
                algo[comp] = algo.get(comp, 0) + p
                continue
            t, r, d, cx, p = cases[2], cases[3], cases[4], cases[5], int(cases[6])
            if t in ("—", "-"):
                if p:
                    err.append("ligne %d : %s compté en double mais %d points" % (no, cases[0], p))
                continue
            if t not in POIDS or (genre == "D") != (t in ("ILF", "EIF")):
                err.append("ligne %d : %s, type %s" % (no, cases[0], t))
                continue
            k = complexite(t, int(r), int(d))
            if cx != CPLX[k]:
                err.append("ligne %d : %s, complexité %s, attendue %s" % (no, cases[0], cx, CPLX[k]))
            if p != POIDS[t][k]:
                err.append("ligne %d : %s, %d points, attendus %d" % (no, cases[0], p, POIDS[t][k]))
            pf.setdefault(comp, {}).setdefault(t, 0)
            pf[comp][t] += p
            nb.setdefault(comp, {}).setdefault(t, 0)
            nb[comp][t] += 1
        except (ValueError, IndexError):
            err.append("ligne %d : %s mal formée" % (no, cases[0]))
    return pf, algo, nb, err


def fr(n):
    return "{:,}".format(n).replace(",", " ")


def tableaux(journal):
    lignes = {}
    nfich = {}
    for c, rel in fichiers():
        r = compter(rel)
        t = lignes.setdefault(c, [0, 0, 0, 0, 0])
        for i in range(5):
            t[i] += r[i]
        nfich[c] = nfich.get(c, 0) + 1
    o, sysb = octets()
    doc, aide = documentation()
    par, tous, periode = commits(journal)
    livres, ecrits = reutilisation()
    pf, algo, nb, err = points_de_fonction()
    tot_pf = {c: sum(pf.get(c, {}).values()) for c in ORDRE}

    m = []
    m.append("| Composant | Fichiers | Code | Commentaires | Vides | Générées | % comment. | Octets produits | Code / PF | Octets / PF |")
    m.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    cumul = [0] * 7
    for g, liste in GROUPES:
        for c in liste:
            co, cm, vi, ge, bi = lignes.get(c, [0] * 5)
            ob = o.get(c, 0)
            p = tot_pf.get(c, 0)
            m.append("| %s | %d | %s | %s | %s | %s | %d %% | %s | %s | %s |" % (
                NOMS[c], nfich.get(c, 0), fr(co), fr(cm), fr(vi), fr(ge),
                round(100 * cm / (co + cm)) if co + cm else 0, fr(ob) if ob else "—",
                fr(round(co / p)) if p else "—", fr(round(ob / p)) if p and ob else "—"))
            for i, v in enumerate((nfich.get(c, 0), co, cm, vi, ge, ob, p)):
                cumul[i] += v
    m.append("| **Total** | %d | %s | %s | %s | %s | %d %% | %s | %s | %s |" % (
        cumul[0], fr(cumul[1]), fr(cumul[2]), fr(cumul[3]), fr(cumul[4]),
        round(100 * cumul[2] / (cumul[1] + cumul[2])), fr(cumul[5]),
        fr(round(cumul[1] / cumul[6])) if cumul[6] else "—",
        fr(round(cumul[5] / cumul[6])) if cumul[6] else "—"))
    m.append("")
    if sysb:
        m.append("Octets du système : code résident %s (`$C000-$%04X`), page `$FF00` %s, "
                 "chargeur d'amorçage %s ; le reste : les commandes `.COM` du système. "
                 "Exemples : HELLO et GTEST seulement (les `.GRX` et `.LOG` sont interprétés) ; "
                 "données binaires des exemples (`.ANI`, `.HIZ`, `.SPR`, `.GIF`) : %s octets." % (
                     fr(sysb["code"]), 0xC000 + sysb["code"], fr(sysb["ff"]), fr(sysb.get("boot", 0)),
                     fr(lignes.get("EX", [0] * 5)[4])))
        m.append("")
    m.append("| Composant | Documentation (lignes) | Aide de HELP (entrées) | Doc / PF | Commits |")
    m.append("|---|---:|---:|---:|---:|")
    for c in ORDRE + ["TRA", "EN"]:
        p = tot_pf.get(c, 0)
        m.append("| %s | %s | %s | %s | %s |" % (
            NOMS[c], fr(doc.get(c, 0)), aide.get(c, 0) or "—",
            ("%.1f" % (doc.get(c, 0) / p)).replace(".", ",") if p else "—",
            par.get(c, 0) if par is not None else "—"))
    m.append("| **Total** | %s | %d | %s | %s |" % (
        fr(sum(doc.values())), sum(aide.values()),
        ("%.1f" % (sum(doc.values()) / cumul[6])).replace(".", ",") if cumul[6] else "—",
        tous if tous is not None else "—"))
    m.append("")
    m.append("Lignes de documentation : lignes non vides de `docs/*.md` (`manuel.md` réparti par "
             "section), `README.md`, `CLAUDE.md` ; aide de HELP : entrées de `tools/gen_readme_txt.py`. "
             "Un commit compte pour chaque composant qu'il touche (la colonne ne s'additionne pas).")
    if periode:
        m.append("")
        m.append("Historique : %d commits du %s au %s." % (tous, periode[0], periode[1]))
    m.append("")
    m.append("Réutilisation : %s lignes de code écrites dans `progs/`, %s lignes assemblées dans "
             "les `.COM` (bibliothèques incluses comptées dans chaque programme qui les inclut) : "
             "taux %s (sans compter les bibliothèques que GRXASM recopie dans les programmes traduits)." % (
                 fr(ecrits), fr(livres), ("%.2f" % (livres / ecrits if ecrits else 0)).replace(".", ",")))

    s = []
    s.append("| Composant | ILF | EIF | EI | EO | EQ | **PF IFPUG** | Algorithmes | **Total** |")
    s.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    gt = [0] * 8
    for g, liste in GROUPES:
        st = [0] * 8
        for c in liste:
            v = [pf.get(c, {}).get(t, 0) for t in ("ILF", "EIF", "EI", "EO", "EQ")]
            a = algo.get(c, 0)
            row = v + [sum(v), a, sum(v) + a]
            s.append("| %s | %s | **%d** | %d | **%d** |" % (
                NOMS[c], " | ".join(str(x) for x in v), row[5], a, row[7]))
            st = [x + y for x, y in zip(st, row)]
        if len(liste) > 1:
            s.append("| *%s* | %s | ***%d*** | *%d* | ***%d*** |" % (
                g, " | ".join("*%d*" % x for x in st[:5]), st[5], st[6], st[7]))
        gt = [x + y for x, y in zip(gt, st)]
    s.append("| **Total** | %s | **%d** | **%d** | **%d** |" % (
        " | ".join("**%d**" % x for x in gt[:5]), gt[5], gt[6], gt[7]))
    s.append("")
    n = {t: sum(nb.get(c, {}).get(t, 0) for c in ORDRE) for t in POIDS}
    s.append("Points ajustés (indicatif, § 9) : %s × %s ≈ %s." % (
        fr(gt[5]), str(FACTEUR).replace(".", ","), fr(round(gt[5] * FACTEUR))))
    s.append("")
    s.append("Nombre de fonctions comptées : %s." % ", ".join("%d %s" % (n[t], t) for t in POIDS))
    c = []
    c.append("| Domaine | CP/A PF | CP/A algo. | CP/A total | CP/M 2.2 PF | CP/M algo. | CP/M total | CP/A / CP/M |")
    c.append("|---|---:|---:|---:|---:|---:|---:|---:|")
    sa = [0] * 6
    for dom, ca, cm in COMPARAISON:
        a = sum(tot_pf.get(x, 0) for x in ca), sum(algo.get(x, 0) for x in ca)
        b = sum(sum(pf.get(x, {}).values()) for x in cm), sum(algo.get(x, 0) for x in cm)
        v = [a[0], a[1], a[0] + a[1], b[0], b[1], b[0] + b[1]]
        sa = [x + y for x, y in zip(sa, v)]
        c.append("| %s | %s | %s |" % (dom, " | ".join(str(x) for x in v),
                                        ("%.1f" % (v[2] / v[5])).replace(".", ",") if v[5] else "—"))
    c.append("| **Total** | %s | **%s** |" % (" | ".join("**%d**" % x for x in sa),
                                            ("%.1f" % (sa[2] / sa[5])).replace(".", ",") if sa[5] else "—"))
    return "\n".join(m), "\n".join(s), "\n".join(c), err


def remplacer(texte, marque, contenu):
    a, b = "<!-- %s:debut -->" % marque, "<!-- %s:fin -->" % marque
    i, j = texte.find(a), texte.find(b)
    if i < 0 or j < 0:
        sys.exit("marques %s absentes de %s" % (marque, DOC))
    return texte[:i + len(a)] + "\n" + contenu + "\n" + texte[j:]


def main():
    journal = None
    if "--git-log" in sys.argv:
        journal = sys.argv[sys.argv.index("--git-log") + 1]
    mes, syn, cmp, err = tableaux(journal)
    if err:
        print("\n".join(err))
        sys.exit(1)
    if "--ecrire" in sys.argv:
        t = open(DOC, encoding="utf-8").read()
        t = remplacer(remplacer(remplacer(t, "mesures", mes), "synthese", syn), "comparaison", cmp)
        open(DOC, "w", encoding="utf-8").write(t)
        print("docs/points-de-fonction.md mis à jour")
    else:
        print(syn)
        print()
        print(mes)
        print()
        print(cmp)


if __name__ == "__main__":
    main()
