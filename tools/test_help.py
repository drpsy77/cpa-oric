#!/usr/bin/env python3
"""HELP.COM : chaque mot mène à sa page.

  python3 tools/test_help.py [--tout]

HELP.COM (build/progs, build/progs-en) tourne dans le 6502 simulé
(tools/run_com.py) ; la première ligne affichée est comparée au titre de
la page attendue (tools/gen_readme_txt.py) :
1. HELP seul : la page d'accueil ;
2. chaque mot général (commandes, noms de pages, synonymes) ;
3. pour chaque vocabulaire (GRAPHER, LOGO) : le premier et le dernier mot de
   chaque page (--tout : tous les mots), en entier et par son début ;
4. refus : mot inconnu, mot d'un vocabulaire donné seul, mot inconnu dans
   un vocabulaire, second mot après une page sans vocabulaire.
"""
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

R = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, R)
import gen_readme_txt as G                   # noqa: E402

DOSSIER = {"fr": os.path.join(R, "..", "build", "progs"),
           "en": os.path.join(R, "..", "build", "progs-en")}


def help_(code, args):
    """-> lignes affichées par HELP args"""
    p = subprocess.run([sys.executable, os.path.join(R, "run_com.py"), DOSSIER[code], "HELP.COM"] + args,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return [l for l in p.stdout.decode("latin-1").replace("\r", "").split("\n") if not l.startswith("[")]


def cas(code, tout):
    """-> [(arguments, inconnu attendu, titre attendu)]"""
    plat, index, vocab = G.structure(code)
    titre = lambda p: plat[p][1]
    out = [([], False, titre(0)), (["ZZZ"], True, titre(0)), ([index[0][0], "ZZZ"], True, titre(index[0][1]))]
    for m, p in index:
        out.append(([m], False, titre(p)))
    generaux = set(m for m, p in index)
    for page, mots in vocab:
        nom = plat[page][0]
        par_page = {}
        for m, p in mots:
            par_page.setdefault(p, []).append(m)
        for p, ms in sorted(par_page.items()):
            for m in (ms if tout else [ms[0], ms[-1]]):
                out.append(([nom, m], False, titre(p)))
                if not any(g.startswith(G.cle(m)) for g in generaux):
                    out.append(([m], True, titre(0)))       # hors de son vocabulaire
            # le début d'un mot : le premier de la table qui commence ainsi
            m = ms[-1]
            if len(m) > 2:
                debut = m[:-1]
                premier = next(q for k, q in mots if k.startswith(debut))
                out.append(([nom, debut], False, titre(premier)))
        out.append(([nom, "ZZZ"], True, titre(page)))
    return out


def essai(job):
    code, args, inconnu, attendu = job
    lignes = help_(code, args)
    vu_inconnu = bool(lignes) and lignes[0] == G.LANGUES[code]["inconnu"]
    vu = lignes[2] if vu_inconnu and len(lignes) > 2 else (lignes[0] if lignes else "")
    if vu_inconnu == inconnu and vu == attendu:
        return None
    return "%s HELP %s : %s%s, attendu %s%s" % (code, " ".join(args), "(inconnu) " if vu_inconnu else "", vu,
                                               "(inconnu) " if inconnu else "", attendu)


def main():
    tout = "--tout" in sys.argv[1:]
    ko = 0
    for code in ("fr", "en"):
        jobs = [(code,) + c for c in cas(code, tout)]
        with ThreadPoolExecutor(os.cpu_count() or 2) as ex:
            res = [r for r in ex.map(essai, jobs) if r]
        for r in res:
            print("ECHEC : " + r)
        ko += len(res)
        print("%s : %d essais, %d echec(s)" % (code, len(jobs), len(res)))
    sys.exit(1 if ko else 0)


if __name__ == "__main__":
    main()
