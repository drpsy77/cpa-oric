#!/usr/bin/env python3
"""Vitrine de la console à distance : CP/A montré en boucle, sans personne.

Tape sur l'Oric par le démon (tools/remote.py, interface du § 9.1 de
docs/console-distance.md), comme quelqu'un qui s'en servirait : commandes,
complétion, aide, menus FUNCT, EDIT sur un programme GRAPHER, EDSPRITE sur
DUN.SPR (ou un autre .SPR de la disquette), CMDER, DEBUG,
USBDIR, et deux programmes en mode texte (LORES) : MOSAIQUE (tuiles de
couleur) et HORLOGE (l'heure, tapée par la vitrine : l'Oric n'a pas
d'horloge). Rythme : une scène de spectacle (HORLOGE, MOSAIQUE, EDIT,
DEBUG, CMDER, EDSPRITE), puis deux commandes au prompt, et ainsi de suite, moins
d'une seconde entre deux ; scènes tirées au hasard dans chaque groupe, la
frappe a un rythme humain : les spectateurs de la page web voient un Oric
en direct, pas une vidéo.

    python3 tools/vitrine.py [--demon URL] [--humain S] [--scenes a,b,...]
                             [--langue fr|en] [--une] [--liste]

    --demon URL    le démon (défaut http://localhost:8040)
    --humain S     pause tant que quelqu'un d'autre a tapé depuis moins de
                   S secondes (défaut 120 ; page web, fenêtre, ligne de
                   commande : tout ce qui n'est pas la vitrine)
    --scenes ...   seulement ces scènes (noms : --liste)
    --langue L     langue du système de l'Oric (défaut : reconnue par la
                   barre des menus, Systeme ou System)
    --une          chaque scène une fois, dans l'ordre, puis fin (essai)

Sur l'Oric : CP/A au prompt, console à distance active (REMOTE hote), sur
une disquette où l'on peut écrire : la vitrine y écrit MOSAIQUE.GRX et
HORLOGE.GRX (dans EDIT, à la vue de tous) s'ils manquent ; sur un système
anglais, MOSAIC.GRX et CLOCK.GRX (tools/vitrine/en, textes en anglais). CMDER efface
parfois l'un des deux (filtre sur son nom, DEL, O) ; la scène de spectacle
suivante le retape dans EDIT, puis le lance. Rien d'autre n'est écrit,
effacé ni modifié.
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
SH_D, SH_B, SH_H, CT_B, CT_H = 0xF1, 0xF2, 0xF3, 0xF6, 0xF7  # SHIFT et CTRL, flèches
CTRL = {c: ord(c) - 64 for c in "ACDEFOQSVWXZ"}
CTRL["H"] = 28                                  # ^H, ^I, ^J, ^K : 28-31 (contrat)
PROGRAMMES = ("MOSAIQUE", "HORLOGE")    # rôles ; noms sur la disquette : TEXTES
# Textes de l'Oric que la vitrine lit ou tape, selon la langue du système
# (cpa.dsk, cpa-en.dsk) ; reconnue au démarrage par la barre des menus.
TEXTES = {
    "fr": {"barre": "Systeme", "suite": "-- Suite", "edit_nouveau": "Nouveau",
           "edit_titre": "Fichier", "cmder": "ESC fin", "filtre": "Filtre",
           "effacer": "Effacer", "on": "(O/N)", "oui": "O", "quitter": "Quitter (O/N)",
           "aide": ["", "touches", "edit", "cmder", "usb", "prog", "edsprite"],
           "noms": {"MOSAIQUE": "MOSAIQUE", "HORLOGE": "HORLOGE"}, "dossier": "vitrine",
           "heure": "Heure ?",
           "echo": ["echo Il est %d h %02d a Paris", "echo %dh%02d : l'Oric est en direct"]},
    "en": {"barre": "System", "suite": "-- More", "edit_nouveau": "New file",
           "edit_titre": "File", "cmder": "ESC quit", "filtre": "Filter",
           "effacer": "Erase", "on": "(Y/N)", "oui": "Y", "quitter": "Quit (Y/N)",
           "aide": ["", "keys", "edit", "cmder", "usb", "prog", "edsprite"],
           "noms": {"MOSAIQUE": "MOSAIC", "HORLOGE": "CLOCK"}, "dossier": "vitrine/en",
           "heure": "Time ?",
           "echo": ["echo It is %d:%02d in Paris", "echo %d:%02d - live from an Oric"]},
}


class Humain(Exception):
    """Quelqu'un d'autre tape : la scène s'arrête."""


class Vitrine:
    def __init__(self, url, humain, langue=None):
        self.url = url.rstrip("/")
        self.humain = humain
        self.e = None
        self.manquants = set()          # programmes absents de la disquette
        self.sprites = []               # fichiers .SPR de la disquette
        self.langue = langue            # None : reconnue au démarrage
        self.t = TEXTES[langue or "fr"]

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
            if suite and self.t["suite"] in t:
                time.sleep(random.uniform(0.8, 1.6))   # le temps de lire
                self.envoyer([32])
            time.sleep(0.25)
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

    def pause(self, a=0.3, b=1.0):
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
        """Langue du système (barre des menus, sauf --langue) ; note les
        programmes de la vitrine absents de la disquette : la première scène
        qui s'en sert les écrit."""
        self.retour_prompt()
        if self.langue is None:
            barre = self.lignes()[0]
            self.t = TEXTES["fr" if TEXTES["fr"]["barre"] in barre else
                            "en" if TEXTES["en"]["barre"] in barre else "fr"]
            print(time.strftime("%H:%M:%S"), "langue :",
                  [k for k, v in TEXTES.items() if v is self.t][0], flush=True)
        presents = self.fichiers("*.grx")
        self.manquants = set(n for n in PROGRAMMES if self.nom(n) + ".GRX" not in presents)
        self.sprites = sorted(n for n in self.fichiers("*.spr") if n.endswith(".SPR"))

    def retaper(self, nom):
        """Écrit le programme nom (MOSAIQUE, HORLOGE) dans EDIT, à la vue de
        tous : texte collé, ^S, ^Q."""
        f = self.nom(nom).lower() + ".grx"
        texte = open(os.path.join(ICI, self.t["dossier"], f), encoding="ascii").read()
        self.taper("edit " + f)
        self.attendre(lambda li: self.t["edit_nouveau"] in li[27] or self.t["edit_titre"] in li[0],
                      30, suite=False)
        time.sleep(1)
        self.coller(texte)
        dernier = [l for l in texte.splitlines() if l.strip()][-1].strip()[:20]
        self.attendre(dernier, 300, suite=False)
        time.sleep(1)
        self.touche(CTRL["S"], apres=3)
        self.touche(CTRL["Q"], apres=1)
        if self.attendre_prompt(30):
            self.manquants.discard(nom)
            return True
        return False

    def present(self, nom):
        """Le programme nom est sur la disquette ; sinon il est retapé."""
        if nom in self.manquants:
            if not self.retaper(nom):
                return False
            self.retour_prompt()
        return True

    def programmes(self):
        """Fichiers .GRX de la vitrine présents sur la disquette."""
        return [self.nom(n).lower() + ".grx" for n in PROGRAMMES if n not in self.manquants]

    def nom(self, role):
        """Nom sur la disquette du programme MOSAIQUE ou HORLOGE (selon la
        langue : MOSAIC, CLOCK en anglais)."""
        return self.t["noms"][role]

    # --- scènes ----------------------------------------------------------------------
    def s_heure(self):
        """HORLOGE : l'heure en grands chiffres, tapée par la vitrine."""
        if not self.present("HORLOGE"):
            return
        self.taper("grapher %s %d" % (self.nom("HORLOGE").lower(), random.randint(15, 25)))
        if not self.attendre(self.t["heure"], 40, suite=False):
            return
        t = time.localtime()
        # trois INPUT sur la ligne 2, colonnes 10, 15 et 18 : chacun attendu
        # (case en vidéo inverse) avant d'y taper, comme quelqu'un qui regarde
        # l'écran ; une frappe arrivée avant l'INPUT peut le dérouter
        for col, quoi in ((10, "h"), (15, "m"), (18, "s")):
            if not self.attendre(lambda li: self.octet(2, col) & 0x80, 10, suite=False):
                break                               # la reprise ramènera au prompt
            time.sleep(random.uniform(0.2, 0.5))
            if quoi == "s":                         # au moment de la taper
                t = time.localtime(time.time() + 0.5)
            v = {"h": t.tm_hour, "m": t.tm_min, "s": t.tm_sec}[quoi]
            self.taper("%02d" % v)
        self.attendre_prompt(60)

    def octet(self, n, col):
        """Octet de la ligne n, colonne col, du dernier état lu."""
        return bytes.fromhex(self.e["lignes"][str(n)])[col]

    def s_echo_heure(self):
        """L'heure au prompt, par ECHO."""
        t = time.localtime()
        self.commande(random.choice(self.t["echo"]) % (t.tm_hour, t.tm_min))

    def s_mosaique(self):
        """MOSAIQUE : tuiles de couleur en LORES."""
        if not self.present("MOSAIQUE"):
            return
        self.taper("grapher %s %d" % (self.nom("MOSAIQUE").lower(), random.randint(2, 3)))
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
        self.commande("type " + random.choice(self.programmes() + ["readme.txt"]), 90)

    def s_aide(self):
        """HELP, une rubrique."""
        self.commande("help " + random.choice(self.t["aide"]), 90)

    def s_menus(self):
        """Menus FUNCT : la barre, les menus déroulés, refermés."""
        for _ in range(random.randint(2, 3)):
            self.touche(FUNCT, apres=1.2)           # la barre
            for _ in range(random.randint(0, 3)):
                self.touche(D, apres=0.9)           # menu suivant
            self.touche(B, apres=1.0)               # déroulé
            for _ in range(random.randint(1, 4)):
                self.touche(B, apres=0.7)
            time.sleep(1)
            self.touche(ESC, apres=1.0)             # fermé
        # (pas de RETURN dans un menu : la barre se rouvre sur le dernier menu
        # vu, et le premier article d'Ecran est Mode SPLIT)
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
            time.sleep(random.uniform(1.5, 2.5))
        self.taper("q")
        self.attendre_prompt(20)

    def s_edit(self):
        """EDIT sur un programme GRAPHER : on le parcourt, on cherche, on quitte
        sans rien changer."""
        noms = self.programmes()
        if not noms:
            return self.present(random.choice(PROGRAMMES))
        nom = random.choice(noms)
        self.taper("edit " + nom)
        if not self.attendre(nom.upper(), 30, suite=False):
            return self.retour_prompt()
        time.sleep(1)
        for _ in range(random.randint(4, 10)):
            self.touche(B, apres=0.3)
        for _ in range(random.randint(1, 3)):
            self.touche(SH_B, apres=1.5)
        for _ in range(random.randint(3, 8)):
            self.touche(D, apres=0.15)
        self.touche(CT_H, apres=1.0)
        self.touche(CTRL["F"], apres=0.8)           # chercher
        self.taper(random.choice(["SUB", "LOCATE", "PRINT"]))
        time.sleep(1.2)
        if random.random() < 0.5:
            self.touche(7, apres=1.2)               # ^G : suivant
        time.sleep(1)
        self.touche(CTRL["Q"], apres=1.0)
        if not self.attendre_prompt(5):             # une question : ne pas enregistrer
            self.touche(ord("N"), apres=1.0)
            self.retour_prompt()

    def s_edsprite(self):
        """EDSPRITE sur DUN.SPR (sinon un autre .SPR) : grille, codes, copie du
        sprite retournée (miroir horizontal), décor, animation ; on quitte sans
        enregistrer : la scène se rejoue à l'identique."""
        if not self.sprites:
            return self.s_edit()
        nom = "DUN.SPR" if "DUN.SPR" in self.sprites else random.choice(self.sprites)
        self.taper("edsprite " + nom[:-4].lower())
        if not self.attendre(nom, 30, suite=False):
            return self.retour_prompt()
        time.sleep(1)
        for _ in range(random.randint(6, 12)):      # le curseur dans la grille
            self.touche(random.choice([D, D, B, B, G, H, SH_D, SH_B]), apres=0.2)
        self.touche(CTRL["H"], apres=2.0)           # codes hexadécimaux
        self.touche(CTRL["H"], apres=0.8)           # et retour à la liste
        self.touche(TAB, apres=0.8)                 # la liste des sprites
        self.touche(CTRL["C"], apres=0.6)           # copier le sprite
        self.touche(CTRL["V"], apres=1.2)           # coller : la copie, après lui
        self.touche(RET, apres=0.8)                 # sa grille
        self.menu(3, 1)                             # Dessin, Miroir horizontal
        time.sleep(1.5)
        self.menu(4, 1)                             # Vue, Décor (au suivant)
        self.menu(4, 2)                             # Vue, Animer
        time.sleep(random.uniform(2.5, 4))
        self.touche(ESC, apres=0.8)                 # une touche arrête
        self.touche(CTRL["Q"], apres=1.0)
        if not self.attendre_prompt(3):             # « Fichier modifie. Quitter (O/N) ? »
            if self.attendre(lambda li: any(self.t["quitter"] in l for l in li), 3, suite=False):
                self.touche(ord(self.t["oui"]), apres=1.0)  # sans enregistrer
            else:
                self.touche(ESC, apres=0.5)
            if not self.attendre_prompt(5):
                self.retour_prompt()

    def menu(self, rang_menu, rang):
        """Menu FUNCT n° rang_menu (0 le premier), article rang (0 le premier)."""
        self.touche(FUNCT, apres=0.8)
        for _ in range(rang_menu):
            self.touche(D, apres=0.3)
        self.touche(B, apres=0.6)                   # déroulé, sur le premier article
        for _ in range(rang):
            self.touche(B, apres=0.4)
        self.touche(RET, apres=1.2)

    def s_cmder(self):
        """CMDER : le gestionnaire de fichiers, tris, déplacements ; efface
        parfois MOSAIQUE.GRX ou HORLOGE.GRX (retapé ensuite dans EDIT)."""
        self.taper("cmder")
        if not self.attendre(self.t["cmder"], 30, suite=False):
            return self.retour_prompt()
        time.sleep(1)
        for _ in range(random.randint(3, 8)):
            self.touche(B, apres=0.3)
        self.touche(random.choice([ord("2"), ord("3"), ord("4")]), apres=1.5)
        for _ in range(random.randint(2, 6)):
            self.touche(random.choice([B, B, H]), apres=0.4)
        self.touche(ord("?"), apres=2.0)            # infos du fichier (ligne d'état)
        if not self.manquants and random.random() < 0.6:
            self.effacer(random.choice(PROGRAMMES))
        else:
            self.touche(9 if random.random() < 0.5 else B, apres=1.0)
            time.sleep(1)
        self.touche(ESC, apres=0.8)
        self.attendre_prompt(15)

    def filtre(self, motif):
        """CMDER : filtre de la colonne active (/ ; le filtre actuel, proposé,
        effacé par DEL ; motif vide : sans filtre)."""
        self.touche(ord("/"), apres=0.8)
        if not self.attendre(self.t["filtre"], 5, suite=False):
            return False
        for _ in range(14):                         # NOM.EXT avec lecteur : 14 au plus
            self.envoyer([DEL])
            time.sleep(0.05)
        time.sleep(0.4)
        self.taper(motif)
        time.sleep(1)
        return True

    def effacer(self, role):
        """CMDER : filtre sur le .GRX du programme (MOSAIQUE, HORLOGE), DEL,
        O ; puis sans filtre. On ne répond O que si la question nomme bien ce
        fichier."""
        nom = self.nom(role)
        fichier = nom + ".GRX"
        if not self.filtre(fichier.lower()):
            return
        if self.attendre(lambda li: any(nom in l for l in li[2:24]), 5, suite=False):
            self.touche(DEL, apres=1.0)
            if self.attendre(lambda li: any(self.t["effacer"] in l and nom in l and self.t["on"] in l
                                            for l in li), 5, suite=False):
                time.sleep(0.8)
                self.touche(ord(self.t["oui"]), apres=1.5)
                self.manquants.add(role)
            else:
                self.touche(ESC, apres=0.5)
        self.filtre("")

    def s_divers(self):
        """VER, MEM, CLS."""
        self.commande(random.choice(["ver", "mem", "cls", "ver"]))

    # scènes : (fonction, poids, spectacle) ; une de spectacle, puis deux
    # commandes au prompt, et ainsi de suite
    SCENES = {"heure": (s_heure, 3, True), "mosaique": (s_mosaique, 3, True),
              "edit": (s_edit, 2, True), "debug": (s_debug, 1, True),
              "cmder": (s_cmder, 2, True), "edsprite": (s_edsprite, 2, True),
              "dir": (s_dir, 2, False), "completion": (s_completion, 2, False),
              "type": (s_type, 1, False), "aide": (s_aide, 1, False),
              "menus": (s_menus, 2, False), "usb": (s_usb, 2, False),
              "echo": (s_echo_heure, 1, False), "divers": (s_divers, 2, False)}
    COMMANDES_PAR_SPECTACLE = 2

    def suivante(self, noms, rang, precedente):
        """Scène du rang donné : spectacle au rang 0, 3, 6... ; un programme
        effacé par CMDER passe en premier (il est retapé, puis lancé)."""
        spectacle = rang % (self.COMMANDES_PAR_SPECTACLE + 1) == 0
        groupe = [n for n in noms if self.SCENES[n][2] == spectacle] or list(noms)
        if spectacle:
            for nom, scene in (("MOSAIQUE", "mosaique"), ("HORLOGE", "heure")):
                if nom in self.manquants and scene in groupe and scene != precedente:
                    return scene
        choix = [n for n in groupe if n != precedente] or groupe
        return random.choices(choix, [self.SCENES[n][1] for n in choix])[0]

    def jouer(self, nom):
        f = self.SCENES[nom][0]
        print(time.strftime("%H:%M:%S"), nom, flush=True)
        if self.etat()["mode"] & 0x7F:      # SPLIT ou HIRES restés d'avant : texte
            self.retour_prompt()
            self.taper("text")
            self.attendre(lambda li: not self.e["mode"] & 0x7F, 15, suite=False)
        if not self.retour_prompt():
            print("   pas de prompt", flush=True)
            return
        f(self)

    def boucle(self, noms, une=False):
        prepare = False
        precedente = None
        rang = 0
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
                    nom = self.suivante(noms, rang, precedente)
                    rang += 1
                precedente = nom
                self.jouer(nom)
                self.pause()
            except Humain:
                print(time.strftime("%H:%M:%S"), "quelqu'un tape : pause", flush=True)
                time.sleep(10)
            except OSError as err:
                print(time.strftime("%H:%M:%S"), "demon injoignable :", err, flush=True)
                time.sleep(10)


def main(args):
    url, humain, noms, une = "http://localhost:8040", 120.0, list(Vitrine.SCENES), False
    langue = None
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
        elif a == "--langue":
            langue = args[i + 1]
            i += 1
            if langue not in TEXTES:
                print("langue : fr ou en")
                return 1
        elif a == "--une":
            une = True
        elif a == "--liste":
            for n, (f, p, sp) in Vitrine.SCENES.items():
                print("%-11s %s %s" % (n, "*" if sp else " ", f.__doc__.split("\n")[0]))
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
        return Vitrine(url, humain, langue).boucle(noms, une)
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
