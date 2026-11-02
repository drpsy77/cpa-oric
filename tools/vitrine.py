#!/usr/bin/env python3
"""Vitrine de la console à distance : CP/A montré en boucle, sans personne.

Tape sur l'Oric par le démon (tools/remote.py, interface du § 9.1 de
docs/console-distance.md), comme quelqu'un qui s'en servirait : commandes,
complétion, aide, menus FUNCT, EDIT sur un programme GRAPHER, CMDER, DEBUG,
USBDIR, et deux programmes en mode texte (LORES) : MOSAIQUE (tuiles de
couleur) et HORLOGE (l'heure, tapée par la vitrine : l'Oric n'a pas
d'horloge). Les scènes et les pauses sont tirées au hasard, la frappe a un
rythme humain : les spectateurs de la page web voient un Oric en direct,
pas une vidéo.

    python3 tools/vitrine.py [--demon URL] [--humain S] [--scenes a,b,...]
                             [--une] [--liste]

    --demon URL    le démon (défaut http://localhost:8040)
    --humain S     pause tant que quelqu'un d'autre a tapé depuis moins de
                   S secondes (défaut 120 ; page web, fenêtre, ligne de
                   commande : tout ce qui n'est pas la vitrine)
    --scenes ...   seulement ces scènes (noms : --liste)
    --une          chaque scène une fois, dans l'ordre, puis fin (essai)

Sur l'Oric : CP/A au prompt, console à distance active (REMOTE hote), sur
une disquette où l'on peut écrire : la vitrine y écrit MOSAIQUE.GRX et
HORLOGE.GRX (dans EDIT, à la vue de tous) s'ils manquent. Rien d'autre
n'est écrit ; aucune scène n'efface ni ne modifie de fichier.
Bibliothèque standard seulement (Mac, Raspberry Pi).
"""
import json
import os
import random
import re
import sys
import time
import urllib.request

ICI = os.path.dirname(os.path.abspath(__file__))
RET, ESC, TAB, FUNCT, DEL = 13, 27, 29, 0x80, 0x7F
G, D, B, H = 8, 9, 10, 11                       # flèches
SH_B, SH_H, CT_B, CT_H = 0xF2, 0xF3, 0xF6, 0xF7  # SHIFT et CTRL avec les flèches
CTRL = {c: ord(c) - 64 for c in "ACDEFOQSWXZ"}


class Humain(Exception):
    """Quelqu'un d'autre tape : la scène s'arrête."""


class Vitrine:
    def __init__(self, url, humain):
        self.url = url.rstrip("/")
        self.humain = humain
        self.e = None

    # --- démon ---------------------------------------------------------------
    def _http(self, chemin, corps=None):
        req = urllib.request.Request(self.url + chemin, data=corps,
                                     method="POST" if corps is not None else "GET",
                                     headers={"X-Vitrine": "1"})
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.read()

    def etat(self):
        self.e = json.loads(self._http("/ecran?depuis=0"))
        h = self.e.get("humain")
        if h is not None and h < self.humain:
            raise Humain()
        return self.e

    def lignes(self):
        e = self.etat()
        return ["".join(chr(c & 0x7F) if 32 <= (c & 0x7F) < 127 else " "
                        for c in bytes.fromhex(e["lignes"][str(n)])) for n in range(28)]

    def texte(self):
        return "\n".join(self.lignes())

    def envoyer(self, codes):
        self._http("/touches", bytes(codes))

    # --- frappe ----------------------------------------------------------------
    def touche(self, *codes, apres=0.35):
        for k in codes:
            self.envoyer([k])
            time.sleep(apres * random.uniform(0.7, 1.4))

    def taper(self, texte, entree=True):
        """Frappe à un rythme humain : 5 à 12 touches par seconde, une
        hésitation de temps en temps."""
        for ch in texte:
            self.envoyer([ord(ch)])
            p = random.uniform(0.08, 0.2)
            if ch == " " or random.random() < 0.06:
                p += random.uniform(0.1, 0.5)
            time.sleep(p)
        if entree:
            time.sleep(random.uniform(0.2, 0.6))
            self.envoyer([RET])

    def coller(self, texte):
        self._http("/coller", texte.encode("utf-8"))

    # --- attentes --------------------------------------------------------------
    def attendre(self, cible, delai=30, suite=True):
        """Attend un texte (ou une condition sur les lignes) ; répond aux
        pauses de fin d'écran (« -- Suite ») par une espace."""
        fin = time.time() + delai
        while time.time() < fin:
            li = self.lignes()
            t = "\n".join(li)
            if callable(cible) and cible(li) or not callable(cible) and cible in t:
                return True
            if suite and "-- Suite" in t:
                time.sleep(random.uniform(1.5, 3.5))   # le temps de lire
                self.envoyer([32])
            time.sleep(0.4)
        return False

    def ligne_curseur(self):
        li = self.lignes()
        cx, cy, _ = self.e["curseur"]
        return li[cy][2:cx] if cy < 28 else ""

    def au_prompt(self):
        return bool(re.fullmatch(r"[A-D]>", self.ligne_curseur()))

    def attendre_prompt(self, delai=60):
        return self.attendre(lambda li: self.au_prompt(), delai)

    def retour_prompt(self):
        """Ramène au prompt, ligne vide : ESC, puis ^C, puis démarrage à chaud."""
        if self.au_prompt():
            return True
        if self.attendre(lambda li: self.au_prompt(), 3, suite=False):
            return True                     # un programme qui se termine
        for codes in ([ESC], [ESC], [CTRL["Q"]], [3], [RET]):
            self.envoyer(codes)             # le système se recharge en quelques secondes
            if self.attendre(lambda li: self.au_prompt(), 10):
                return True
        self._http("/reset", b"")
        return self.attendre_prompt(20)

    def commande(self, texte, delai=60):
        self.taper(texte)
        return self.attendre_prompt(delai)

    def pause(self, a=2.0, b=6.0):
        fin = time.time() + random.uniform(a, b)
        while time.time() < fin:
            self.etat()                 # Humain si quelqu'un tape
            time.sleep(0.5)

    # --- préparation ---------------------------------------------------------------
    def fichiers(self, motif):
        """Noms (NOM.EXT) listés par DIR motif."""
        self.taper("dir " + motif)
        self.attendre_prompt(30)
        t = self.texte()
        return set(n + "." + x for n, x in re.findall(r"([A-Z0-9_$-]{1,8}) *\.([A-Z0-9_$]{1,3})", t))

    def preparer(self):
        """Écrit les programmes de la vitrine sur la disquette s'ils manquent,
        dans EDIT, à la vue de tous."""
        self.retour_prompt()
        presents = self.fichiers("*.grx")
        for nom in ("MOSAIQUE", "HORLOGE"):
            if nom + ".GRX" in presents:
                continue
            texte = open(os.path.join(ICI, "vitrine", nom.lower() + ".grx"), encoding="ascii").read()
            self.taper("edit %s.grx" % nom.lower())
            self.attendre(lambda li: "Nouveau" in li[27] or "Fichier" in li[0], 30, suite=False)
            time.sleep(2)
            self.coller(texte)
            dernier = [l for l in texte.splitlines() if l.strip()][-1].strip()[:20]
            self.attendre(dernier, 300, suite=False)
            time.sleep(2)
            self.touche(CTRL["S"], apres=4)
            self.touche(CTRL["Q"], apres=1)
            self.attendre_prompt(30)

    # --- scènes ----------------------------------------------------------------------
    def s_heure(self):
        """HORLOGE : l'heure en grands chiffres, tapée par la vitrine."""
        self.taper("grapher horloge %d" % random.randint(20, 35))
        if not self.attendre("Heure ?", 40, suite=False):
            return
        time.sleep(random.uniform(0.5, 1.5))
        t = time.localtime(time.time() + 1.5)       # frappe et lecture des trois nombres
        for v in (t.tm_hour, t.tm_min, t.tm_sec):
            self.envoyer([ord(c) for c in "%02d" % v] + [RET])
            time.sleep(0.3)
        self.attendre_prompt(60)

    def s_echo_heure(self):
        """L'heure au prompt, par ECHO."""
        t = time.localtime()
        self.commande(random.choice(["echo Il est %d h %02d a Paris",
                                     "echo %dh%02d : l'Oric est en direct"]) % (t.tm_hour, t.tm_min))

    def s_mosaique(self):
        """MOSAIQUE : tuiles de couleur en LORES."""
        self.taper("grapher mosaique %d" % random.randint(2, 4))
        self.attendre_prompt(150)

    def s_dir(self):
        """DIR, DIRS, STAT."""
        self.commande(random.choice(["dir", "dir *.com", "dir *.grx", "dirs", "stat *.grx",
                                     "stat"]))

    def s_completion(self):
        """Complétion par TAB : commande, puis nom de fichier, puis TYPE."""
        self.taper("ty", entree=False)
        time.sleep(0.6)
        self.touche(TAB, apres=0.8)
        noms = [n for n in self.fichiers_vus() if n.endswith((".GRX", ".TXT", ".BAT", ".LOG"))]
        nom = random.choice(noms) if noms else "README.TXT"
        self.taper(nom[:2].lower(), entree=False)
        time.sleep(0.6)
        self.touche(TAB, apres=1.2)
        if nom not in self.ligne_curseur().upper():  # plusieurs choix : la liste, puis le nom
            self.taper(nom[2:].lower(), entree=False)
        self.touche(RET, apres=0.5)
        self.attendre_prompt(90)

    def fichiers_vus(self):
        return set(n + "." + x for n, x in re.findall(r"([A-Z0-9_$-]{1,8}) *\.([A-Z0-9_$]{1,3})",
                                                       self.texte()))

    def s_type(self):
        """TYPE d'un programme ou d'un texte."""
        self.commande("type " + random.choice(["mosaique.grx", "horloge.grx", "readme.txt"]), 90)

    def s_aide(self):
        """HELP, une rubrique."""
        self.commande("help " + random.choice(["", "touches", "edit", "cmder", "usb", "prog"]), 90)

    def s_menus(self):
        """Menus FUNCT : la barre, les menus déroulés, puis Version."""
        for _ in range(random.randint(2, 3)):
            self.touche(FUNCT, apres=1.2)           # la barre
            for _ in range(random.randint(0, 3)):
                self.touche(D, apres=0.9)           # menu suivant
            self.touche(B, apres=1.0)               # déroulé
            for _ in range(random.randint(1, 4)):
                self.touche(B, apres=0.7)
            time.sleep(1)
            self.touche(ESC, apres=1.0)             # fermé
        if random.random() < 0.6:                   # Systeme, Version
            self.touche(FUNCT, apres=1.0)
            self.touche(B, apres=1.0)
            self.touche(RET, apres=1.0)
        self.retour_prompt()

    def s_usb(self):
        """USBDIR : la clé du LOCI."""
        self.commande(random.choice(["usbdir", "usbdir /s", "usbmount"]), 30)

    def s_debug(self):
        """DEBUG : le système en $C000, l'écran lui-même en $BB80."""
        self.taper("debug mem")
        if not self.attendre(lambda li: self.ligne_curseur() == "-", 30, suite=False):
            return self.retour_prompt()
        time.sleep(1)
        for cmd in random.sample(["l c000", "d bb80", "l 0500", "l e000", "? bb80", "r",
                                  "d 0200"], 3):
            self.taper(cmd)
            time.sleep(random.uniform(3, 5))
        self.taper("q")
        self.attendre_prompt(20)

    def s_edit(self):
        """EDIT sur un programme GRAPHER : on le parcourt, on cherche, on quitte
        sans rien changer."""
        nom = random.choice(["mosaique.grx", "horloge.grx"])
        self.taper("edit " + nom)
        if not self.attendre(nom.upper(), 30, suite=False):
            return self.retour_prompt()
        time.sleep(2)
        for _ in range(random.randint(4, 10)):
            self.touche(B, apres=0.3)
        for _ in range(random.randint(1, 3)):
            self.touche(SH_B, apres=1.5)
        for _ in range(random.randint(3, 8)):
            self.touche(D, apres=0.15)
        self.touche(CT_H, apres=1.5)
        self.touche(CTRL["F"], apres=1.0)           # chercher
        self.taper(random.choice(["SUB", "LOCATE", "PRINT"]))
        time.sleep(2)
        if random.random() < 0.5:
            self.touche(7, apres=1.5)               # ^G : suivant
        time.sleep(2)
        self.touche(CTRL["Q"], apres=1.5)
        if not self.attendre_prompt(5):             # une question : ne pas enregistrer
            self.touche(ord("N"), apres=1.0)
            self.retour_prompt()

    def s_cmder(self):
        """CMDER : le gestionnaire de fichiers, tris, déplacements."""
        self.taper("cmder")
        if not self.attendre("ESC fin", 30, suite=False):
            return self.retour_prompt()
        time.sleep(2)
        for _ in range(random.randint(3, 8)):
            self.touche(B, apres=0.4)
        self.touche(random.choice([ord("2"), ord("3"), ord("4")]), apres=2.0)
        for _ in range(random.randint(2, 6)):
            self.touche(random.choice([B, B, H]), apres=0.5)
        self.touche(ord("?"), apres=3.0)            # infos du fichier (ligne d'état)
        self.touche(9 if random.random() < 0.5 else B, apres=1.0)
        time.sleep(2)
        self.touche(ESC, apres=1.0)
        self.attendre_prompt(15)

    def s_divers(self):
        """VER, MEM, CLS."""
        self.commande(random.choice(["ver", "mem", "cls", "ver"]))

    SCENES = {"heure": (s_heure, 3), "echo": (s_echo_heure, 1), "mosaique": (s_mosaique, 3),
              "dir": (s_dir, 2), "completion": (s_completion, 2), "type": (s_type, 1),
              "aide": (s_aide, 1), "menus": (s_menus, 2), "usb": (s_usb, 1),
              "debug": (s_debug, 1), "edit": (s_edit, 2), "cmder": (s_cmder, 2),
              "divers": (s_divers, 1)}

    def jouer(self, nom):
        f = self.SCENES[nom][0]
        print(time.strftime("%H:%M:%S"), nom, flush=True)
        if not self.retour_prompt():
            print("   pas de prompt", flush=True)
            return
        f(self)

    def boucle(self, noms, une=False):
        prepare = False
        precedente = None
        file = list(noms) if une else []
        while True:
            try:
                e = self.etat()
                if e["liaison"] != "active":
                    print(time.strftime("%H:%M:%S"), "liaison", e["liaison"], flush=True)
                    time.sleep(10)
                    continue
                if not prepare:
                    self.preparer()
                    prepare = True
                if une:
                    if not file:
                        return 0
                    nom = file.pop(0)
                else:
                    choix = [n for n in noms if n != precedente]
                    nom = random.choices(choix, [self.SCENES[n][1] for n in choix])[0]
                precedente = nom
                self.jouer(nom)
                self.pause(3, 15)
            except Humain:
                print(time.strftime("%H:%M:%S"), "quelqu'un tape : pause", flush=True)
                time.sleep(10)
            except OSError as err:
                print(time.strftime("%H:%M:%S"), "demon injoignable :", err, flush=True)
                time.sleep(10)


def main(args):
    url, humain, noms, une = "http://localhost:8040", 120.0, list(Vitrine.SCENES), False
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--demon":
            url = args[i + 1]
            i += 1
        elif a == "--humain":
            humain = float(args[i + 1])
            i += 1
        elif a == "--scenes":
            noms = args[i + 1].split(",")
            i += 1
        elif a == "--une":
            une = True
        elif a == "--liste":
            for n, (f, p) in Vitrine.SCENES.items():
                print("%-11s %s" % (n, f.__doc__.split("\n")[0]))
            return 0
        else:
            print(__doc__)
            return 1
        i += 1
    for n in noms:
        if n not in Vitrine.SCENES:
            print("scene inconnue : %s (--liste)" % n)
            return 1
    try:
        return Vitrine(url, humain).boucle(noms, une)
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
