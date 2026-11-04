#!/usr/bin/env python3
"""Console à distance de CP/A, fenêtre tkinter (Mac, Pi 400, Raspberry Pi Zero).

Client du démon (tools/remote.py, ou tools/faux_demon.py pour les essais) :
affiche l'écran de l'Oric tenu par le démon et lui envoie les touches.
Même rôle que la page web (docs/console-distance.md § 9), sans navigateur :
pour un Pi Zero et son petit écran. Python 3 et tkinter seulement.

    python3 tools/remote_tk.py [options]

    --demon URL       démon à joindre (défaut http://localhost:8040)
    --mem VIDAGE.mem  montre un vidage de tools/run_test.sh, sans démon
    --plein-ecran     occupe tout l'écran (petit écran du Pi Zero) ; F11 bascule
    --etirer          remplit la place sans garder les proportions
    --echelle E       échelle imposée (1, 2, 1.5...) ; sinon la plus grande
                      qui tient (entière à partir de 2)
    --sans-boutons    pas de barre de boutons (touches : F1 FUNCT, F5 RESET)
    --pixels P        tele (défaut : points 1,23 fois plus larges que hauts,
                      comme sur un téléviseur PAL) ou carres
    --couleurs C      tele (défaut : couleurs d'un téléviseur) ou pures (00/FF)

Touches : comme le clavier de l'Oric (flèches, avec SHIFT ou CTRL ; CTRL +
lettre ; Entrée, Échap, Retour arrière, Tab) ; F1 FUNCT ; F5 démarrage à
chaud ; F9 Coller (presse-papiers) ; F11 plein écran ; F10 quitte.
"""
import json
import os
import queue
import sys
import threading
import time
import tkinter as tk
import urllib.request
from urllib.error import URLError

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oric_ecran as oe  # noqa: E402

COLS, ROWS, LARG, HAUT = oe.COLS, oe.ROWS, oe.LARG, oe.HAUT
CLIGN = 0.32                    # demi-période du clignotement (s)

# Codes du contrat (architecture.md § 2, « Codes du clavier »)
FLECHES = {"Left": 0, "Right": 1, "Down": 2, "Up": 3}
FUNCT = 0x80


# Ordre dans lequel les points d'une case sont doublés quand la case grandit
# d'une fraction : d'abord la colonne d'espacement (5) et la rangée vide du
# bas (7), puis réparties ; quand elle rétrécit, elles partent les premières.
PRIO_COL = [5, 0, 2, 4, 1, 3]
PRIO_RANG = [7, 3, 0, 5, 2, 6, 1, 4]


def repartir(n, base, prio):
    """Nombre de points de sortie pour chacun des `base` points d'une case de n points."""
    if n < base:                       # rétrécie : on garde les premiers
        return [1 if k < n else 0 for k in range(base)]
    c = [n // base] * base
    for k in prio[:n % base]:
        c[k] += 1
    return c


def code_touche(ev):
    """Événement tkinter -> code de touche de l'Oric (None : rien à envoyer)."""
    shift, ctrl = bool(ev.state & 1), bool(ev.state & 4)
    ks = ev.keysym
    if ks in FLECHES:
        base = 0xF4 if ctrl else 0xF0 if shift else 0x08
        return base + FLECHES[ks]
    simples = {"Return": 13, "KP_Enter": 13, "Escape": 27, "BackSpace": 0x7F,
               "Delete": 0x7F, "Tab": 29, "ISO_Left_Tab": 29}
    if ks in simples:
        return simples[ks]
    if ctrl:
        if len(ks) == 1 and ks.isalpha():
            n = ord(ks.upper()) - 64
            return n + 20 if 8 <= n <= 11 else n          # CTRL-H..K : 28-31
        if ks in ("space", "at"):
            return 0
        if ks == "bracketleft":
            return 27
        return None
    ch = ev.char
    if len(ch) == 1:
        if 32 <= ord(ch) < 127:
            return ord(ch)
        a = oe.ascii_oric(ch)                              # é -> e
        if len(a) == 1:
            return a[0]
    return None


class Demon:
    """Liaison avec le démon : un fil pour l'écran (attente longue), un pour
    les envois (dans l'ordre). Les résultats passent par une file."""

    def __init__(self, url):
        self.url = url.rstrip("/")
        self.recus = queue.Queue()
        self.envois = queue.Queue()
        threading.Thread(target=self._lire, daemon=True).start()
        threading.Thread(target=self._envoyer, daemon=True).start()

    def _lire(self):
        version = 0
        while True:
            try:
                with urllib.request.urlopen("%s/ecran?depuis=%d&attendre=1" % (self.url, version),
                                            timeout=5) as r:
                    e = json.loads(r.read())
                if e["version"] < version:          # démon relancé : tout reprendre
                    version = 0
                    continue
                version = e["version"]
                self.recus.put(("ecran", e))
            except (URLError, OSError, ValueError) as err:
                version = 0
                self.recus.put(("erreur", str(getattr(err, "reason", err))))
                time.sleep(2)

    def _envoyer(self):
        while True:
            chemin, corps = self.envois.get()
            try:
                req = urllib.request.Request(self.url + chemin, data=corps, method="POST")
                urllib.request.urlopen(req, timeout=5).read()
            except (URLError, OSError) as err:
                self.recus.put(("erreur", "envoi : %s" % getattr(err, "reason", err)))

    def touches(self, codes):
        self.envois.put(("/touches", bytes(codes)))

    def coller(self, texte):
        self.envois.put(("/coller", texte.encode("utf-8")))

    def reset(self):
        self.envois.put(("/reset", b""))


class Fenetre:
    def __init__(self, racine, opts):
        self.r = racine
        self.opts = opts
        self.hex = oe.HEX if opts["couleurs"] == "pures" else oe.HEX_TELE
        self.par = 1 if opts["pixels"] == "carres" else oe.PAR_TELE
        self.police_cpa = oe.charger_police()
        self.police, self.alt = self.police_cpa, None
        self.memoire = [None] * 48              # police envoyée par l'Oric
        self.lignes = [bytes(COLS)] * ROWS
        self.mode = 0
        self.curseur = [0, 0, False]
        self.liaison = "attente"
        self.message = "Connexion au demon..."
        self.eteint = False             # phase du clignotement
        self.echelle = None
        self.cache = {}

        racine.title("CP/A a distance")
        racine.configure(bg="black")
        self.etat = tk.Label(racine, text="", anchor="w", bg="#202020", fg="#c0c0c0",
                             font=("TkFixedFont", 9))
        self.etat.pack(side="top", fill="x")
        if not opts["sans_boutons"]:
            barre = tk.Frame(racine, bg="#202020")
            barre.pack(side="bottom", fill="x")
            for t, f in (("FUNCT", lambda: self.envoyer([FUNCT])),
                         ("CTRL-C", lambda: self.envoyer([3])),
                         ("ESC", lambda: self.envoyer([27])),
                         ("RESET", self.reset), ("Coller", self.coller)):
                tk.Button(barre, text=t, command=f, takefocus=0, padx=4, pady=0,
                          font=("TkDefaultFont", 9)).pack(side="left", padx=2, pady=2)
        self.toile = tk.Canvas(racine, bg="black", highlightthickness=0)
        self.toile.pack(fill="both", expand=True)
        self.img = None
        self.fond = self.toile.create_rectangle(0, 0, 0, 0, fill="#303030", outline="#808080",
                                                state="hidden")
        self.texte = self.toile.create_text(0, 0, text="", fill="#ffffff",
                                            font=("TkFixedFont", 11), justify="center")
        self.toile.bind("<Configure>", lambda ev: self.mettre_a_l_echelle(ev.width, ev.height))
        racine.bind("<Key>", self.touche)
        racine.bind("<F10>", lambda ev: racine.destroy())
        racine.bind("<F11>", self.bascule_plein_ecran)
        racine.bind("<F1>", lambda ev: self.envoyer([FUNCT]))
        racine.bind("<F5>", lambda ev: self.reset())
        racine.bind("<F9>", lambda ev: self.coller())
        if opts["plein_ecran"]:
            # sans gestionnaire de fenêtres (X lancé seul, tools/pizero_ecran.sh),
            # -fullscreen ne fait rien : la taille de l'écran est posée aussi
            racine.geometry("%dx%d+0+0" % (racine.winfo_screenwidth(),
                                           racine.winfo_screenheight()))
            racine.attributes("-fullscreen", True)
            racine.configure(cursor="none")
            self.toile.configure(cursor="none")
            racine.after(200, racine.focus_force)
        else:
            racine.geometry("%dx%d" % (round(LARG * 2 * self.par), HAUT * 2 + 50))

        self.demon = None
        if opts["mem"]:
            mem = open(opts["mem"], "rb").read()
            e = oe.ecran_depuis_vidage(mem)
            self.appliquer({"version": 1, "liaison": "vidage", "hote": opts["mem"],
                            "mode": e["mode"], "curseur": e["curseur"], "delai": 0,
                            "lignes": {str(n): l.hex() for n, l in enumerate(e["lignes"])},
                            "police": {} if e["mode"] & 0x7F else    # police du mode texte
                            {str(k): mem[0xB400 + 40 * k:0xB428 + 40 * k].hex() for k in range(48)}})
        else:
            self.demon = Demon(opts["demon"])
            self.r.after(20, self.relever)
        self.r.after(int(CLIGN * 1000), self.clignoter)

    # --- géométrie -----------------------------------------------------------
    def mettre_a_l_echelle(self, w, h):
        if w < 10 or h < 10:
            return
        # Taille d'une case (cw x ch points), la même pour toutes : une
        # échelle non entière ne déforme pas les lettres d'une ligne à l'autre
        if self.opts["echelle"]:
            ey = self.opts["echelle"]
            ex = ey * self.par
        else:
            ex, ey = w / LARG, h / HAUT
            if not self.opts["etirer"]:          # forme du téléviseur gardée
                ey = min(ex / self.par, ey)
                if ey >= 2:
                    ey = int(ey)
                ex = ey * self.par
        cw, ch = max(1, int(6 * ex)), max(1, int(8 * ey))
        if self.echelle == (cw * COLS, ch * ROWS):
            return
        self.echelle = (cw * COLS, ch * ROWS)
        lw, lh = self.echelle
        self.reps = repartir(cw, 6, PRIO_COL) * COLS      # points par point de l'Oric
        rr = repartir(ch, 8, PRIO_RANG)
        self.rangs_sortie = [r for r in range(8) for _ in range(rr[r])]
        self.y0 = [n * ch for n in range(ROWS + 1)]
        self.cache = {}
        self.img = tk.PhotoImage(width=lw, height=lh)
        self.toile.delete("ecran")
        self.toile.create_image(w // 2, h // 2, image=self.img, tags="ecran")
        self.toile.coords(self.texte, w // 2, h // 2)
        self.toile.tag_raise(self.fond)
        self.toile.tag_raise(self.texte)
        self.dessiner(range(ROWS))
        self.afficher_etat()

    def bascule_plein_ecran(self, ev=None):
        self.r.attributes("-fullscreen", not self.r.attributes("-fullscreen"))

    # --- dessin --------------------------------------------------------------
    def _rang(self, rang):
        """Une rangée de 240 points -> données tkinter à la largeur de sortie."""
        cle = bytes(rang)
        s = self.cache.get(cle)
        if s is None:
            reps = self.reps
            s = "{" + " ".join(self.hex[p] for i, p in enumerate(rang) for _ in range(reps[i])) + "}"
            if len(self.cache) > 4000:
                self.cache = {}
            self.cache[cle] = s
        return s

    def dessiner(self, nums):
        if self.img is None:
            return
        cx, cy, actif = self.curseur
        graphique = self.mode & 0x7F
        for n in nums:
            if graphique == 2 or (graphique == 1 and n < 16):
                rangs = [[0] * LARG for _ in range(8)]       # image : non transmise
                if graphique == 1 or n % 2 == 0:
                    for r in rangs[::2]:
                        r[::2] = [4] * (LARG // 2)
            else:
                l = self.lignes[n]
                if actif and n == cy and cx < COLS and not self.eteint:
                    l = bytearray(l)
                    l[cx] ^= 0x80
                alt = self.alt if graphique == 0 else None
                rangs = oe.rendre_ligne(self.police if graphique == 0 else self.police_cpa,
                                        l, n, self.eteint, alt)
            donnees = [self._rang(rangs[r]) for r in self.rangs_sortie]
            if donnees:
                self.img.put(" ".join(donnees), to=(0, self.y0[n]))

    def clignoter(self):
        self.eteint = not self.eteint
        nums = [n for n in range(ROWS) if oe.ligne_a_clignotement(self.lignes[n])]
        if self.curseur[2] and self.curseur[1] < ROWS and self.curseur[1] not in nums:
            nums.append(self.curseur[1])
        self.dessiner(nums)
        self.r.after(int(CLIGN * 1000), self.clignoter)

    # --- démon ---------------------------------------------------------------
    def relever(self):
        try:
            while True:
                quoi, v = self.demon.recus.get_nowait()
                if quoi == "ecran":
                    self.appliquer(v)
                else:
                    self.message = "Demon injoignable (%s)\n%s" % (v, self.opts["demon"])
                    self.liaison = "?"
                    self.afficher_etat()
        except queue.Empty:
            pass
        self.r.after(20, self.relever)

    def appliquer(self, e):
        ancien_cur, ancien_mode = self.curseur, self.mode
        nums = set()
        for k, h in e.get("lignes", {}).items():
            n = int(k)
            b = bytes.fromhex(h)
            if b != self.lignes[n]:
                self.lignes[n] = b
                nums.add(n)
        pol = e.get("police", {})
        for k, h in pol.items():
            self.memoire[int(k)] = bytes.fromhex(h)
        if pol or nums & {0, 1, 2, 3} and any(self.memoire):
            ancien = (self.police, self.alt)
            self.police, self.alt = oe.polices(self.police_cpa, self.memoire, self.lignes)
            if (self.police, self.alt) != ancien:
                nums = set(range(ROWS))
        self.curseur = list(e["curseur"])
        self.mode = e["mode"]
        self.liaison = e["liaison"]
        self.hote = e.get("hote", "")
        self.delai = e.get("delai", 0)
        if self.mode != ancien_mode:
            nums = set(range(ROWS))
        if ancien_cur[1] != self.curseur[1] or ancien_cur[0] != self.curseur[0]:
            nums.update(n for n in (ancien_cur[1], self.curseur[1]) if n < ROWS)
        self.message = {"attente": "En attente de l'appel de l'Oric\n(REMOTE hote sur l'Oric)",
                        "perdue": "Liaison perdue"}.get(self.liaison, "")
        if (self.mode & 0x7F) == 2:
            self.message = "Ecran graphique (HIRES)"
        self.dessiner(sorted(nums))
        self.afficher_etat()

    def afficher_etat(self):
        voyant = {"active": "R", "perdue": "r"}.get(self.liaison, "-")
        if self.liaison == "vidage":
            t = " vidage %s" % os.path.basename(self.hote)
        else:
            t = " CP/A a distance  %s  %s  %.1f s" % (getattr(self, "hote", ""), voyant,
                                                      getattr(self, "delai", 0) or 0)
        self.etat.configure(text=t.replace(".", ","))
        self.toile.itemconfigure(self.texte, text=self.message)
        if self.message:
            x0, y0, x1, y1 = self.toile.bbox(self.texte)
            self.toile.coords(self.fond, x0 - 8, y0 - 6, x1 + 8, y1 + 6)
            self.toile.itemconfigure(self.fond, state="normal")
        else:
            self.toile.itemconfigure(self.fond, state="hidden")

    # --- clavier -------------------------------------------------------------
    def envoyer(self, codes):
        if self.demon:
            self.demon.touches(codes)

    def touche(self, ev):
        if ev.keysym in ("F1", "F5", "F9", "F10", "F11"):
            return
        k = code_touche(ev)
        if k is not None:
            self.envoyer([k])
        return "break"

    def reset(self):
        if self.demon:
            self.demon.reset()

    def coller(self):
        try:
            texte = self.r.clipboard_get()
        except tk.TclError:
            return
        if self.demon and texte:
            self.demon.coller(texte)


def main(args):
    opts = {"demon": "http://localhost:8040", "mem": None, "plein_ecran": False,
            "etirer": False, "echelle": None, "sans_boutons": False,
            "pixels": "tele", "couleurs": "tele"}
    i = 0
    while i < len(args):
        a = args[i]
        if a in ("--demon", "--mem", "--echelle", "--pixels", "--couleurs"):
            v = args[i + 1]
            opts[a[2:]] = float(v) if a == "--echelle" else v
            i += 2
            continue
        if a in ("--plein-ecran", "--etirer", "--sans-boutons"):
            opts[a[2:].replace("-", "_")] = True
        else:
            print(__doc__.split("\n\n")[2])
            return 1
        i += 1
    racine = tk.Tk()
    Fenetre(racine, opts)
    racine.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
