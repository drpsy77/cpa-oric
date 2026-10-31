#!/usr/bin/env python3
"""Faux démon de la console à distance, pour essayer les clients sans Oric.

Il sert l'interface locale du démon (docs/console-distance.md § 9.1) comme le
fera tools/remote.py, mais l'écran vient d'une mire ou de vidages mémoire
d'Oricutron, et les touches reçues sont affichées ici (et jouées sur une
ligne de commande simulée : on voit l'écho dans le client).

    python3 tools/faux_demon.py [--http 8040] [--periode S] [VIDAGE.mem ...]

    sans vidage : une mire (couleurs, inverse, double hauteur, clignotement,
                  police entière) et une invite A> qui reçoit la frappe
    VIDAGE.mem  : écrans de tools/run_test.sh, passés à tour de rôle toutes
                  les S secondes (défaut 5) ; la frappe va sur le premier

Bibliothèque standard seulement (marche sur un Raspberry Pi Zero).
"""
import json
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

import oric_ecran as oe

COLS, ROWS = oe.COLS, oe.ROWS


def mire():
    """Écran d'essai : tout ce que le rendu doit savoir dessiner."""
    l = [bytearray(b" " * COLS) for _ in range(ROWS)]

    def ecrire(n, col, texte):
        for i, ch in enumerate(texte.encode("ascii") if isinstance(texte, str) else texte):
            l[n][col + i] = ch
    l[0][:] = (bytes([16 + 6, 0]) + b"Systeme Fichiers Ecran Clavier  R  A").ljust(COLS)
    ecrire(1, 2, "CP/A - faux demon (mire d'essai)")
    ecrire(3, 2, "Encres :")
    for i in range(8):
        l[3][12 + 3 * i] = i
        l[3][13 + 3 * i] = ord("0") + i
    ecrire(4, 2, "Papiers :")
    for i in range(8):
        l[4][12 + 3 * i] = 16 + i
        l[4][13 + 3 * i] = ord("0") + i
        l[4][14 + 3 * i] = ord(" ")
    l[4][36] = 16
    ecrire(5, 2, "Inverse : ")
    ecrire(5, 12, bytes(c | 0x80 for c in b"VIDEO INVERSE"))
    ecrire(6, 2, "Clignote :")
    l[6][12] = 12
    ecrire(6, 13, "ATTENTION")
    l[6][22] = 8
    ecrire(6, 24, "fixe")
    for n in (8, 9):
        l[n][2] = 1 + 2      # encre jaune
        l[n][3] = 9          # double hauteur
        ecrire(n, 4, "DOUBLE HAUTEUR")
    ecrire(11, 2, "Police :")
    for k in range(96):
        n, c = 12 + k // 32, 4 + k % 32
        l[n][c] = 32 + k
    ecrire(16, 2, "Les touches recues s'affichent dans")
    ecrire(17, 2, "le terminal du faux demon.")
    ecrire(19, 2, "A>")
    return l, [4, 19, True]


class Ecran:
    """Copie de l'écran tenue par le démon, avec un numéro de version par ligne."""

    def __init__(self, ecrans):
        self.ecrans = ecrans            # liste de (lignes, curseur, mode)
        self.idx = 0
        self.version = 1
        self.vlig = [1] * ROWS
        self.cond = threading.Condition()
        self._poser(*ecrans[0])

    def _poser(self, lignes, curseur, mode):
        self.lignes = [bytearray(x) for x in lignes]
        self.curseur = list(curseur)
        self.mode = mode

    def changer(self, nouv, curseur=None, mode=None):
        """Remplace les lignes changées ; réveille les clients qui attendent."""
        with self.cond:
            self.version += 1
            for n in range(ROWS):
                if nouv[n] != self.lignes[n]:
                    self.lignes[n] = bytearray(nouv[n])
                    self.vlig[n] = self.version
            if curseur is not None:
                self.curseur = list(curseur)
            if mode is not None:
                self.mode = mode
            self.cond.notify_all()

    def suivant(self):
        self.idx = (self.idx + 1) % len(self.ecrans)
        lignes, cur, mode = self.ecrans[self.idx]
        self.changer(lignes, cur, mode)

    def touche(self, k):
        """Ligne de commande simulée : la frappe s'affiche au curseur."""
        l = [bytearray(x) for x in self.lignes]
        cx, cy, act = self.curseur
        if 32 <= k < 127:
            if cx < COLS:
                l[cy][cx] = k
                cx += 1
        elif k == 0x7F and cx > 4:
            cx -= 1
            l[cy][cx] = 32
        elif k == 13:
            cy += 1
            if cy >= ROWS:
                l = l[:1] + l[2:] + [bytearray(b" " * COLS)]
                cy = ROWS - 1
            l[cy][2:4] = b"A>"
            cx = 4
        else:
            return
        self.changer(l, [cx, cy, act])

    def etat(self, depuis, attendre):
        with self.cond:
            if attendre and self.version <= depuis:
                self.cond.wait(attendre)
            lig = {str(n): self.lignes[n].hex() for n in range(ROWS)
                   if self.vlig[n] > depuis or depuis == 0}
            return {"version": self.version, "liaison": "active", "hote": "faux demon",
                    "mode": self.mode, "curseur": self.curseur, "delai": 0.1,
                    "lignes": lig}


def servir(ecran, port):
    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def _rep(self, code, corps=b"", type_="application/json"):
            self.send_response(code)
            self.send_header("Content-Type", type_)
            self.send_header("Content-Length", str(len(corps)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(corps)

        def do_GET(self):
            u = urlparse(self.path)
            q = parse_qs(u.query)
            if u.path == "/ecran":
                depuis = int(q.get("depuis", ["0"])[0])
                attendre = min(float(q.get("attendre", ["0"])[0]), 5.0)
                self._rep(200, json.dumps(ecran.etat(depuis, attendre)).encode())
            else:
                self._rep(404, b"inconnu\n", "text/plain")

        def do_POST(self):
            n = int(self.headers.get("Content-Length", "0"))
            corps = self.rfile.read(n)
            u = urlparse(self.path).path
            if u == "/touches":
                print("touches :", " ".join("%02X" % k for k in corps), flush=True)
                for k in corps:
                    ecran.touche(k)
            elif u == "/coller":
                codes = oe.ascii_oric(corps.decode("utf-8", "replace"))
                print("coller : %d touches" % len(codes), flush=True)
                for k in codes:
                    ecran.touche(k)
            elif u == "/reset":
                print("demarrage a chaud ($FD 'B')", flush=True)
            else:
                self._rep(404, b"inconnu\n", "text/plain")
                return
            self._rep(204)

    srv = ThreadingHTTPServer(("", port), H)
    srv.daemon_threads = True
    print("faux demon : http://localhost:%d/ecran" % port, flush=True)
    srv.serve_forever()


def main(args):
    port, periode = 8040, 5.0
    if "--http" in args:
        i = args.index("--http"); port = int(args[i + 1]); del args[i:i + 2]
    if "--periode" in args:
        i = args.index("--periode"); periode = float(args[i + 1]); del args[i:i + 2]
    if args:
        ecrans = []
        for f in args:
            e = oe.ecran_depuis_vidage(open(f, "rb").read())
            ecrans.append((e["lignes"], e["curseur"], e["mode"]))
    else:
        l, cur = mire()
        ecrans = [(l, cur, 0)]
    ecran = Ecran(ecrans)
    if len(ecrans) > 1:
        def tourner():
            while True:
                time.sleep(periode)
                ecran.suivant()
        threading.Thread(target=tourner, daemon=True).start()
    try:
        servir(ecran, port)
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
