#!/usr/bin/env python3
"""Sûreté des fichiers : scénarios d'enregistrement qui tournent mal, joués
dans Oricutron (tools/run_test.sh), pour EDIT et GRAPHER (SAVE, BSAVE,
BSAVE SCREEN).

  python3 tools/test_fichiers.py [--vite] [--garde DOSSIER] [filtre...]

Chaque scénario part d'une disquette préparée ici (tools/mkdisk.py : système,
GRAPHER.COM, EDIT.COM, EDIT.CFG, les programmes d'essai de
tools/fichiers_tests/, l'ancien fichier, et ce qu'il faut pour remplir le
disque ou le répertoire), tape une commande, puis regarde la disquette
(mkdisk check et diff, contenu du fichier visé) et l'écran (message).

Attendu partout : l'ancien fichier intact, ou le nouveau complet ; jamais un
fichier perdu ou abîmé ; pas de NOM.$$$ qui reste ; un message juste ;
« mkdisk.py check » sans défaut. Après un RESET pendant l'écriture,
NOM.$$$ peut rester (il est effacé par l'enregistrement suivant du même
nom) : c'est compté à part, pas comme un échec.

RESET balayé : le bouton RESET (\\x06 de run_test.sh) est appuyé N trames
après la commande, N d'abord de 10 en 10 pour trouver la fenêtre où la
disquette change, puis trame par trame dans cette fenêtre (de 3 en 3 avec
--vite). Les préfixes de touche \\x0f (SHIFT) servent d'attente : chacun
prend une trame sans rien taper.

--garde DOSSIER : garde les disquettes, vidages et captures de chaque essai.
filtre : ne joue que les scénarios dont le nom contient l'un des mots.
Code de retour : 0 si tout est vert.
"""
import os
import subprocess
import sys
import tempfile
import threading
from concurrent.futures import ThreadPoolExecutor

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(ICI)
sys.path.insert(0, ICI)
import mkdisk as M          # noqa: E402

BUILD = os.path.join(RACINE, "build")
ESSAIS = os.path.join(ICI, "fichiers_tests")
KEYS_AT = 400               # la disquette démarre en ~6 s
VITE = "--vite" in sys.argv
PARALLELE = 2

# ---------------------------------------------------------------- disquettes

ANCIEN_TXT = b"ANCIEN CONTENU, A GARDER INTACT\r\n" * 50          # 1 650 octets, 1 bloc
ANCIEN_BIN = bytes((i * 7) & 0xFF for i in range(1500))
GROS = b"".join(b"Ligne %04d d'un texte trop long pour EDIT (32 000 octets).\r\n" % i
                for i in range(680))                                 # 40 Ko : tronqué
PLEIN = b"".join(b"Ligne %03d : 41 octets en memoire, 42 ici\r\n" % i
                 for i in range(780))      # 32 760 octets, 31 980 en memoire (zone : 32 000)
DOC = b"".join(b"Ligne %02d du document d'essai, assez longue pour remplir.\r\n" % i
               for i in range(90))                                   # 5,4 Ko, 3 blocs


def disque(fichiers, libres=None, entrees_libres=None):
    """fichiers : [(nom, contenu, R/O)] ; libres : blocs laissés libres
    (fichiers de remplissage) ; entrees_libres : entrées du répertoire
    laissées libres."""
    d = M.Disk()
    boot = open(os.path.join(BUILD, "boot.bin"), "rb").read()
    syst = open(os.path.join(BUILD, "cpa_sys.bin"), "rb").read()
    for k in range(3):
        d.sec[k] = boot[k * 256:(k + 1) * 256]
    for k in range(64):
        d.sec[M.SYS_LSN + k] = syst[k * 256:(k + 1) * 256]
    d.format_dir()
    for f in ("progs/GRAPHER.COM", "progs/EDIT.COM"):
        d.write_file(os.path.basename(f), open(os.path.join(BUILD, f), "rb").read())
        d.set_attr(os.path.basename(f), ro=True)
    d.write_file("EDIT.CFG", open(os.path.join(RACINE, "files/edit.cfg"), "rb").read())
    for f in ("t.grx", "e.grx"):
        d.write_file(f.upper(), open(os.path.join(ESSAIS, f), "rb").read())
    for nom, data, ro in fichiers:
        d.write_file(nom, data)
        if ro:
            d.set_attr(nom, ro=True)
    if entrees_libres is not None:
        n = 0
        while sum(1 for e in d.dir_entries() if e[0] == 0xE5) > entrees_libres:
            d.write_file("R%07d.BIN" % n, bytes([n & 0xFF]) * 128)
            n += 1
    if libres is not None:
        n = 0
        while M.NBLK - len(d.used_blocks()) > libres:
            k = min(16, M.NBLK - len(d.used_blocks()) - libres)
            d.write_file("PLEIN%03d.BIN" % n, bytes([0xAA]) * (k * 2048))
            n += 1
    return d


# ------------------------------------------------------------------ essais

_lance = threading.Lock()


def nb_trames(touches):
    """Trames prises par la frappe (run_test.sh) : 8 par touche, 1 par
    préfixe (\\x1c, \\x0f), 150 par pause |, 50 après RESET."""
    n = 0
    for c in touches:
        if c in "\x1c\x0f":
            n += 1
        elif c == "|":
            n += 150
        elif c == "\x06":
            n += 50
        else:
            n += 8
    return n


def essai(dsk_avant, touches, sortie, apres=900):
    """Joue les touches sur une copie de dsk_avant ; vidage `apres`
    trames après la dernière touche. Rend (disque après, texte de l'écran)."""
    with _lance:                    # un écran virtuel à la fois au lancement
        env = dict(os.environ, DSK=dsk_avant, ORIC_KEYS_AT=str(KEYS_AT), ORIC_WARP="1")
        p = subprocess.Popen([os.path.join(ICI, "run_test.sh"), touches,
                              str(KEYS_AT + nb_trames(touches) + apres), sortie],
                             env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        threading.Event().wait(1.0)
    out = p.communicate()[0]
    if p.returncode or not os.path.exists(sortie + ".mem"):
        raise SystemExit("run_test.sh : échec (%s)\n%s" % (sortie, out.decode(errors="replace")))
    ecran = subprocess.run([sys.executable, os.path.join(ICI, "screen.py"), sortie + ".mem"],
                           capture_output=True, text=True).stdout
    return M.Disk.load(sortie + ".dsk"), ecran


def contenu(d, nom):
    if not d.find(M.Disk.name83(nom)):
        return None
    return d.read_file(nom)


def restes(d):
    return sorted(M.nom_lisible(n) for n in d.listing() if n[8:] == "$$$")


def verif(d):
    """(défauts de check, texte de check)"""
    import io
    import contextlib
    f = io.StringIO()
    with contextlib.redirect_stdout(f):
        r = M.check(d)
    return r, f.getvalue()


def etat(d, cible, ancien, nouveau):
    c = contenu(d, cible)
    if ancien is not None:                  # (complété à 128 par mkdisk)
        ancien = ancien + b"\x1a" * (-len(ancien) % 128)
    if c is None:
        return "perdu"
    if c == ancien:
        return "ancien"
    if nouveau is not None and c == nouveau:
        return "nouveau"
    return "abime (%d octets)" % len(c)


# --------------------------------------------------------------- scénarios
#
# Un scénario : nom, programme, disquette, touches, fichier visé, ce qui
# est attendu dans le fichier ("ancien", "nouveau", "absent"), message
# attendu à l'écran (minuscules, None : pas de contrôle), message interdit.

def S(nom, prog, fichiers, touches, cible, attendu, message=None, interdit=None,
      libres=None, entrees=None, ref=None, autres=(), nouveau=None):
    return dict(nom=nom, prog=prog, fichiers=fichiers, touches=touches, cible=cible,
                attendu=attendu, message=message, interdit=interdit, libres=libres,
                entrees=entrees, ref=ref, autres=autres, nouveau=nouveau)


def scenarios():
    L = []
    g = "GRAPHER T %s\n"
    for op, typ, anc in (("SAVE", "TXT", ANCIEN_TXT), ("BSAVE", "DAT", ANCIEN_BIN)):
        c = "CIBLE." + typ
        L += [
            S("%s normal" % op, op, [(c, anc, False)], g % op, c, "nouveau", "fini",
              ref="%s normal" % op),
            S("%s disque plein" % op, op, [(c, anc, False)], g % op, c, "ancien",
              "disque plein", libres=1),
            S("%s nouveau nom, disque plein" % op, op, [], g % op, c, "absent",
              "disque plein", libres=1),
            S("%s repertoire plein" % op, op, [(c, anc, False)], g % op, c, "ancien|nouveau",
              "repertoire plein|fini", entrees=0, ref="%s normal" % op),
            S("%s nouveau nom, repertoire plein" % op, op, [], g % op, c, "absent",
              "repertoire plein", entrees=0),
            S("%s fichier R/O" % op, op, [(c, anc, True)], g % op, c, "ancien",
              "fichier protege"),
            S("%s RESET" % op, op, [(c, anc, False)], g % op, c, "reset",
              ref="%s normal" % op),
        ]
    c = "CIBLE.SCR"
    e = "GRAPHER E\n"
    anc = bytes(range(256)) * 4 + bytes(96)
    L += [
        S("BSAVE SCREEN normal", "SCREEN", [(c, anc, False)], e, c, "nouveau", "fini",
          ref="BSAVE SCREEN normal"),
        S("BSAVE SCREEN disque plein", "SCREEN", [(c, anc, False)], e, c, "ancien|nouveau",
          "disque plein|fini", libres=0, ref="BSAVE SCREEN normal"),
        S("BSAVE SCREEN nouveau nom, disque plein", "SCREEN", [], e, c, "absent",
          "disque plein", libres=0),
        S("BSAVE SCREEN repertoire plein", "SCREEN", [], e, c, "absent",
          "repertoire plein", entrees=0),
        S("BSAVE SCREEN fichier R/O", "SCREEN", [(c, anc, True)], e, c, "ancien",
          "fichier protege"),
        S("BSAVE SCREEN RESET", "SCREEN", [(c, anc, False)], e, c, "reset",
          ref="BSAVE SCREEN normal"),
    ]
    # EDIT : X tapé au début du document, puis CTRL-S ; « Enreg. sous »
    # par le menu Fichier (FUNCT, 5 fois bas, Entrée)
    ed = "EDIT DOC.TXT\n|X\x1cs|"
    sous = "EDIT DOC.TXT\n|\x05\x04\x04\x04\x04\x04\n%s\n|"
    autre = b"AUTRE FICHIER, A NE PAS ECRASER\r\n" * 10
    L += [
        S("EDIT normal", "EDIT", [("DOC.TXT", DOC, False)], ed, "DOC.TXT", "nouveau",
          "enregistre", ref="EDIT normal"),
        S("EDIT disque plein", "EDIT", [("DOC.TXT", DOC, False)], ed, "DOC.TXT", "ancien",
          "disque plein", libres=1),
        S("EDIT repertoire plein", "EDIT", [("DOC.TXT", DOC, False)], ed, "DOC.TXT",
          "ancien", "repertoire plein", entrees=0),
        S("EDIT fichier R/O", "EDIT", [("DOC.TXT", DOC, True)], ed, "DOC.TXT", "ancien",
          "fichier protege"),
        S("EDIT sous un nom nouveau", "EDIT", [("DOC.TXT", DOC, False)],
          sous % "COPIE.TXT", "COPIE.TXT", "nouveau", "enregistre",
          ref="EDIT sous un nom nouveau"),
        S("EDIT sous, depuis un document R/O", "EDIT", [("DOC.TXT", DOC, True)],
          sous % "COPIE.TXT", "COPIE.TXT", "nouveau", "enregistre",
          ref="EDIT sous un nom nouveau"),
        S("EDIT sous un fichier existant, question", "EDIT",
          [("DOC.TXT", DOC, False), ("AUTRE.TXT", autre, False)],
          sous % "AUTRE.TXT", "AUTRE.TXT", "ancien", "remplacer autre.txt (o/n) ?"),
        S("EDIT sous un fichier existant, N", "EDIT",
          [("DOC.TXT", DOC, False), ("AUTRE.TXT", autre, False)],
          sous % "AUTRE.TXT" + "N|", "AUTRE.TXT", "ancien", interdit="enregistre"),
        S("EDIT sous un fichier existant, O", "EDIT",
          [("DOC.TXT", DOC, False), ("AUTRE.TXT", autre, False)],
          sous % "AUTRE.TXT" + "O|", "AUTRE.TXT", "nouveau", "enregistre",
          ref="EDIT sous un nom nouveau"),
        S("EDIT sous un fichier R/O", "EDIT",
          [("DOC.TXT", DOC, False), ("AUTRE.TXT", autre, True)],
          sous % "AUTRE.TXT", "AUTRE.TXT", "ancien", "fichier protege",
          interdit="enregistre"),
        S("EDIT document tronque (40 Ko), CTRL-S", "EDIT", [("GROS.TXT", GROS, False)],
          "EDIT GROS.TXT\n||X\x1cs|", "GROS.TXT", "ancien", "texte tronque"),
        S("EDIT relit un fichier plus gros que sa zone (CR LF)", "EDIT",
          [("PLEIN.TXT", PLEIN, False)], "EDIT PLEIN.TXT\n||X\x1cs|", "PLEIN.TXT",
          "nouveau", "enregistre", interdit="tronque", nouveau=b"x" + PLEIN),
        S("EDIT RESET", "EDIT", [("DOC.TXT", DOC, False)], ed, "DOC.TXT", "reset",
          ref="EDIT normal"),
    ]
    return L


# ------------------------------------------------------------- évaluation

def juger(sc, avant, apres, ecran, refs):
    """Rend (obtenu, liste des échecs)."""
    ancien = dict((n.upper(), c) for n, c, _ in sc["fichiers"]).get(sc["cible"])
    nouveau = refs.get(sc["ref"]) if sc["ref"] else None
    if sc["nouveau"] is not None:           # contenu attendu connu d'avance
        nouveau = sc["nouveau"] + b"\x1a" * (-len(sc["nouveau"]) % 128)
    ech = []
    st = etat(apres, sc["cible"], ancien, nouveau)
    if st == "perdu" and ancien is None:
        st = "absent"
    if sc["attendu"] == "nouveau" and nouveau is None and st.startswith("abime"):
        st = "nouveau"                  # scénario de référence
    if st not in sc["attendu"].split("|"):
        ech.append("fichier : %s" % st)
    r = restes(apres)
    if r:
        ech.append("reste " + ", ".join(r))
    nd, txt = verif(apres)
    if nd:
        ech.append("check : %d défaut(s)" % nd)
    bas = ecran.lower()
    msg = ""
    if sc["message"]:
        ok = [m for m in sc["message"].split("|") if m in bas]
        if not ok:
            ech.append("message absent (%s)" % sc["message"])
        msg = ok[0] if ok else ""
    if sc["interdit"] and sc["interdit"] in bas:
        ech.append("message « %s » affiché" % sc["interdit"])
    obtenu = st + (", « %s »" % msg if msg else "")
    return obtenu, ech


def balayage(sc, base, avant, dossier, refs, final):
    """RESET à N trames après la commande. Rend (obtenu, échecs)."""
    def un(n):
        sortie = os.path.join(dossier, "n%04d" % n)
        d, ecran = essai(base, sc["touches"].rstrip("|") + "\x0f" * n + "\x06", sortie,
                         apres=200)
        return n, d
    res = {}
    # 1) de 10 en 10 jusqu'à ce que la disquette soit dans son état final
    pas = 10
    n0 = 0
    debut = fin = None
    with ThreadPoolExecutor(PARALLELE) as ex:
        while fin is None and n0 < 3000:
            for n, d in ex.map(un, range(n0, n0 + pas * PARALLELE * 2, pas)):
                res[n] = d
                if debut is None and d.sec != avant.sec:
                    debut = n
                if fin is None and d.sec == final.sec:
                    fin = n
            n0 += pas * PARALLELE * 2
        if debut is None or fin is None:
            return "fenetre d'ecriture introuvable", ["balayage"]
        # 2) trame par trame dans la fenêtre
        fin_pas = 3 if VITE else 1
        for n, d in ex.map(un, [n for n in range(max(0, debut - pas), fin + 1, fin_pas)
                                 if n not in res]):
            res[n] = d
    ancien = dict((n.upper(), c) for n, c, _ in sc["fichiers"]).get(sc["cible"])
    nouveau = refs.get(sc["ref"])
    compte = {}
    ech = []
    dollars = 0
    tmp = sc["cible"].rsplit(".", 1)[0] + ".$$$"
    for n in sorted(res):
        d = res[n]
        st = etat(d, sc["cible"], ancien, nouveau)
        if st == "perdu" and nouveau is not None and contenu(d, tmp) == nouveau:
            st = "nouveau en .$$$"      # entre l'effacement et le renommage
        compte[st] = compte.get(st, 0) + 1
        nd, _ = verif(d)
        if st not in ("ancien", "nouveau", "nouveau en .$$$"):
            ech.append("N=%d : %s" % (n, st))
        if nd:
            ech.append("N=%d : check %d défaut(s)" % (n, nd))
        if restes(d):
            dollars += 1
    obtenu = "%d essais, N=%d-%d : " % (len(res), debut - pas if debut >= pas else 0, fin) + \
        ", ".join("%s %d" % kv for kv in sorted(compte.items()))
    if dollars:
        obtenu += " ; $$$ resté %d fois (toléré)" % dollars
    if len(ech) > 6:
        ech = ech[:6] + ["... (%d en tout)" % len(ech)]
    return obtenu, ech


def attendu_texte(sc):
    a = sc["attendu"]
    if a == "reset":
        return "ancien ou nouveau, check OK"
    t = {"ancien": "ancien intact", "nouveau": "nouveau complet", "absent": "rien d'ecrit",
         "ancien|nouveau": "ancien ou nouveau"}[a]
    if sc["message"]:
        t += ", « %s »" % sc["message"].split("|")[0]
    return t


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    garde = None
    if "--garde" in sys.argv:
        garde = sys.argv[sys.argv.index("--garde") + 1]
        args.remove(garde)
    dossier = garde or tempfile.mkdtemp(prefix="cpa_fichiers_")
    os.makedirs(dossier, exist_ok=True)
    tous = scenarios()
    choix = [s for s in tous if not args or any(a.lower() in s["nom"].lower() for a in args)]
    # les références d'abord (contenu du nouveau fichier)
    besoin = {s["ref"] for s in choix if s["ref"]}
    ordre = [s for s in tous if s["nom"] in besoin] + \
        [s for s in choix if s["nom"] not in besoin]
    refs, finals, lignes, echecs = {}, {}, [], 0
    for sc in ordre:
        rep = os.path.join(dossier, "".join(c if c.isalnum() else "_" for c in sc["nom"]))
        os.makedirs(rep, exist_ok=True)
        d = disque(sc["fichiers"], sc["libres"], sc["entrees"])
        base = os.path.join(rep, "avant.dsk")
        d.save(base)
        avant = M.Disk.load(base)
        if sc["attendu"] == "reset":
            obtenu, ech = balayage(sc, base, avant, rep, refs, finals[sc["ref"]])
        else:
            apres, ecran = essai(base, sc["touches"], os.path.join(rep, "essai"))
            obtenu, ech = juger(sc, avant, apres, ecran, refs)
            if sc["ref"] == sc["nom"]:
                refs[sc["nom"]] = contenu(apres, sc["cible"])
                finals[sc["nom"]] = apres
            with open(os.path.join(rep, "rapport.txt"), "w") as f:
                f.write(ecran + "\n== check\n" + verif(apres)[1] + "\n== diff\n")
                import io
                import contextlib
                b = io.StringIO()
                with contextlib.redirect_stdout(b):
                    M.diff(avant, apres)
                f.write(b.getvalue())
        if sc in choix:
            v = "OK" if not ech else "ECHEC"
            echecs += bool(ech)
            lignes.append((sc["nom"], attendu_texte(sc), obtenu, v, ech))
            print("%-5s %s : %s%s" % (v, sc["nom"], obtenu,
                                      "" if not ech else " [" + " ; ".join(ech) + "]"),
                  flush=True)
    print("\n| Scénario | Attendu | Obtenu | |\n|---|---|---|---|")
    for nom, att, obt, v, ech in lignes:
        print("| %s | %s | %s%s | %s |" % (nom, att, obt,
                                           "" if not ech else " — " + " ; ".join(ech), v))
    print("\n%d scénario(s), %d en échec%s" % (len(lignes), echecs,
                                                "" if garde else " (essais dans %s)" % dossier))
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
