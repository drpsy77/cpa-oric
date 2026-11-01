#!/usr/bin/env python3
"""Console à distance de CP/A : le démon, et sa ligne de commande.

L'Oric appelle le démon par son modem (REMOTE hote, port 2324) ; le démon
tient une copie de l'écran de l'Oric, la met à jour en comparant des totaux
(docs/console-distance.md § 3, 4), et sert une interface HTTP locale (§ 9.1)
à la fenêtre tkinter (tools/remote_tk.py), à la page web et à la ligne de
commande ci-dessous.

    remote.py serve [--port 2324] [--http 8040] [--lent]
        le démon ; --lent : un octet toutes les 25 ms vers l'Oric
    remote.py touches TEXTE        frappe, notation de tools/run_test.sh :
        \\n Entrée, ~ DEL, \\x1b ESC, \\x01-\\x04 flèches G D H B, \\x05 FUNCT,
        \\x1c préfixe CTRL, \\x0f préfixe SHIFT, | pause 3 s, \\x06 démarrage
        à chaud ($FD "B") ; les lettres partent telles quelles (pas de
        verrouillage des majuscules)
    remote.py coller FICHIER       texte (UTF-8) envoyé comme une frappe
                                   (accents retirés, fins de ligne en CR)
    remote.py ecran                l'écran en texte, comme tools/screen.py
    remote.py attendre TEXTE [S]   attend que TEXTE paraisse (S secondes,
                                   défaut 30) ; code 1 si absent
    remote.py etat                 le JSON de /ecran
Options des commandes : --demon URL (défaut http://localhost:8040).

Bibliothèque standard seulement (Mac, Raspberry Pi).
"""
import json
import os
import queue
import socket
import sys
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oric_ecran as oe  # noqa: E402

COLS, ROWS = 40, 28
RP_REQ, RP_KEY, RP_FRM = 0xFD, 0xFE, 0xFF
LONGUEUR = {ord("S"): 60, ord("L"): 41}
LOT = 1024              # touches envoyées d'un coup au plus (texte collé)
PAR_TOUCHE = 0.1        # délai de réponse en plus par touche envoyée : la
                        # demande attend que le programme les ait lues
REPOS = 0.5             # cycle au repos
PERDUE = 5.0            # sans trame valide : liaison perdue


def fletcher(octets):
    s1 = s2 = 0
    for b in octets:
        s1 = (s1 + b) & 0xFF
        s2 = (s2 + s1) & 0xFF
    return s1, s2


class Ecran:
    """Copie de l'écran de l'Oric, avec un numéro de version par ligne."""

    def __init__(self):
        self.lignes = [bytearray(COLS) for _ in range(ROWS)]
        self.vlig = [1] * ROWS
        self.version = 1
        self.curseur = [0, 0, False]
        self.mode = 0
        self.liaison = "attente"
        self.hote = ""
        self.t_cycle = None
        self.cond = threading.Condition()

    def _bump(self):
        self.version += 1
        self.cond.notify_all()

    def ligne(self, n, octets):
        with self.cond:
            if self.lignes[n] != octets:
                self.lignes[n] = bytearray(octets)
                self._bump()
                self.vlig[n] = self.version

    def poser(self, mode=None, curseur=None, liaison=None, hote=None):
        with self.cond:
            change = False
            for nom, val in (("mode", mode), ("curseur", curseur),
                             ("liaison", liaison), ("hote", hote)):
                if val is not None and getattr(self, nom) != val:
                    setattr(self, nom, val)
                    change = True
            if change:
                self._bump()

    def cycle_fait(self):
        self.t_cycle = time.time()

    def etat(self, depuis, attendre):
        with self.cond:
            if attendre and self.version <= depuis:
                self.cond.wait(attendre)
            lig = {str(n): bytes(self.lignes[n]).hex() for n in range(ROWS)
                   if depuis == 0 or self.vlig[n] > depuis}
            delai = round(time.time() - self.t_cycle, 1) if self.t_cycle else None
            return {"version": self.version, "liaison": self.liaison, "hote": self.hote,
                    "mode": self.mode, "curseur": list(self.curseur), "delai": delai,
                    "lignes": lig}


class Liaison:
    """Une connexion de l'Oric : demandes, trames, touches."""

    def __init__(self, sock, ecran, envois, lent, journal):
        self.sock = sock
        self.ecran = ecran
        self.envois = envois
        self.lent = lent
        self.log = journal
        self.buf = bytearray()
        self.fini = False
        self.t_trame = time.time()
        self.cy = 0

    # --- octets ----------------------------------------------------------
    def envoyer(self, octets):
        if self.lent:
            for b in octets:
                self.sock.sendall(bytes([b]))
                time.sleep(0.025)
        else:
            self.sock.sendall(bytes(octets))

    def _lire(self, delai):
        self.sock.settimeout(max(delai, 0.01))
        try:
            d = self.sock.recv(4096)
        except socket.timeout:
            return
        if not d:
            raise ConnectionError("liaison coupée par l'Oric")
        self.buf += d

    def trame(self, attendu, n=None, delai=1.0):
        """Attend une trame du type attendu (et de la ligne n) ; les autres
        (réponses en retard, messages du modem, trames abîmées) sont jetées."""
        fin = time.time() + delai
        while True:
            while True:
                i = self.buf.find(RP_FRM)
                if i < 0:
                    self.buf.clear()
                    break
                del self.buf[:i]
                if len(self.buf) < 3:
                    break
                typ, lg = self.buf[1], self.buf[2]
                if LONGUEUR.get(typ) != lg:
                    del self.buf[:1]
                    continue
                if len(self.buf) < lg + 4:
                    break
                donnees = bytes(self.buf[3:3 + lg])
                if (typ + lg + sum(donnees)) & 0xFF != self.buf[3 + lg]:
                    del self.buf[:1]
                    continue
                del self.buf[:lg + 4]
                self.t_trame = time.time()
                if typ == attendu and (n is None or donnees[0] == n):
                    return donnees
            reste = fin - time.time()
            if reste <= 0:
                return None
            self._lire(reste)

    def demande(self, msg, typ, n=None, essais=3, delai=1.0):
        for _ in range(essais):
            self.envoyer(msg)
            d = self.trame(typ, n, delai)
            if d is not None:
                return d
            if time.time() - self.t_trame > PERDUE + delai:
                self.ecran.poser(liaison="perdue")
        return None

    def ligne(self, n):
        d = self.demande([RP_REQ, ord("L"), n], ord("L"), n)
        if d is not None:
            self.ecran.ligne(n, d[1:])
        return d is not None

    # --- touches ---------------------------------------------------------
    def touches(self, attente):
        """Envoie les touches en attente (LOT au plus) ; rend leur nombre.
        Un démarrage à chaud (-1) part tel quel. Le pilote ne lit une touche
        que si le tampon du clavier a de la place : un texte collé part d'un
        coup, et c'est le programme de l'Oric qui donne le rythme."""
        lot = []
        try:
            k = self.envois.get(timeout=attente) if attente else self.envois.get_nowait()
        except queue.Empty:
            return 0
        while True:
            if k < 0:
                lot += [RP_REQ, ord("B")]
            else:
                lot += [RP_KEY, k]
            if len(lot) >= 2 * LOT:
                break
            try:
                k = self.envois.get_nowait()
            except queue.Empty:
                break
        self.envoyer(lot)
        return len(lot) // 2

    # --- boucle ----------------------------------------------------------
    def boucle(self):
        attente = 0
        while not self.fini:
            n = self.touches(attente)
            if 0 < n <= 4:
                self.ligne(self.cy)        # écho rapide : la ligne du curseur
            s = self.demande([RP_REQ, ord("S")], ord("S"),
                             delai=1.0 + (PAR_TOUCHE * n if n > 4 else 0))
            if s is None:
                attente = 0
                continue
            self.ecran.poser(liaison="active")
            mode, cx, cy, actif = s[0], s[1], s[2], bool(s[3])
            self.cy = cy if cy < ROWS else 0
            self.ecran.poser(mode=mode, curseur=[cx, cy, actif])
            change = False
            if mode & 0x7F != 2:
                debut = 16 if mode & 0x7F == 1 else 0   # SPLIT : lignes de texte
                for n in range(debut, ROWS):
                    t = (s[4 + 2 * n], s[5 + 2 * n])
                    if fletcher(self.ecran.lignes[n]) != t:
                        change = True
                        if not self.ligne(n):
                            break
            self.ecran.cycle_fait()
            attente = 0 if change else REPOS


def demon(port, http, lent):
    ecran = Ecran()
    envois = queue.Queue()

    def journal(m):
        print(time.strftime("%H:%M:%S "), m, flush=True)

    def servir_oric():
        srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.bind(("", port))
        srv.listen(4)
        courant = [None, None]
        while True:
            sock, addr = srv.accept()
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
            ancien, fil = courant
            if ancien is not None and fil.is_alive():   # nouvel appel : il remplace
                journal("nouvel appel : la liaison précédente est fermée")
                ancien.fini = True
                try:
                    ancien.sock.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
                fil.join(5)
            journal("appel de %s" % addr[0])
            li = Liaison(sock, ecran, envois, lent, journal)
            ecran.poser(hote=addr[0], liaison="active")

            def tourner(li=li):
                try:
                    li.boucle()
                except (ConnectionError, OSError) as e:
                    journal("fin de la liaison (%s)" % e)
                finally:
                    li.sock.close()
                    if not li.fini:
                        ecran.poser(liaison="perdue")
            fil = threading.Thread(target=tourner, daemon=True)
            courant[:] = [li, fil]
            fil.start()

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
            elif u.path == "/":
                self._rep(200, "<!doctype html><meta charset=utf-8><title>CP/A a distance"
                          "</title><p>CP/A a distance : la page web viendra (lot 4). "
                          "En attendant : tools/remote_tk.py, ou /ecran.".encode(),
                          "text/html; charset=utf-8")
            else:
                self._rep(404, b"inconnu\n", "text/plain")

        def do_POST(self):
            n = int(self.headers.get("Content-Length", "0"))
            corps = self.rfile.read(n)
            u = urlparse(self.path).path
            if u == "/touches":
                codes = corps
            elif u == "/coller":
                codes = oe.ascii_oric(corps.decode("utf-8", "replace"))
            elif u == "/reset":
                codes = None
                envois.put(-1)
            else:
                self._rep(404, b"inconnu\n", "text/plain")
                return
            for k in codes or b"":
                envois.put(k)
            self._rep(204)

    threading.Thread(target=servir_oric, daemon=True).start()
    srv = ThreadingHTTPServer(("", http), H)
    srv.daemon_threads = True
    journal("console a distance : Oric sur le port %d, interface http://localhost:%d"
            % (port, http))
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


# --- ligne de commande ---------------------------------------------------
FLECHES = {1: 8, 2: 9, 3: 11, 4: 10}       # G D H B -> codes du contrat


def codes_touches(texte):
    """Notation de run_test.sh -> liste de codes (int), "|" (pause) ou -1
    (démarrage à chaud)."""
    out = []
    mod = 0                                 # 1 SHIFT, 2 CTRL
    for ch in texte:
        o = ord(ch)
        if o == 0x1C:
            mod |= 2
            continue
        if o == 0x0F:
            mod |= 1
            continue
        if ch == "|":
            out.append("|")
        elif o == 6:
            out.append(-1)
        elif o in FLECHES:
            k = FLECHES[o]
            if mod & 2:
                k = 0xF4 + k - 8
            elif mod & 1:
                k = 0xF0 + k - 8
            out.append(k)
        elif o == 5:
            out.append(0x80)
        elif ch in "\n\r":
            out.append(13)
        elif ch == "~":
            out.append(0x7F)
        elif mod & 2:
            c = ch.upper()
            if c == " " or c == "@":
                out.append(0)
            elif c == "[":
                out.append(27)
            elif "A" <= c <= "Z":
                k = ord(c) - 64
                out.append(k + 20 if 8 <= k <= 11 else k)
        elif mod & 1 and ch.isalpha():
            out.append(ord(ch.swapcase()))
        elif o < 256:
            out.append(o)
        mod = 0
    return out


def http(url, chemin, corps=None, delai=10):
    req = urllib.request.Request(url + chemin, data=corps, method="POST" if corps is not None else "GET")
    with urllib.request.urlopen(req, timeout=delai) as r:
        return r.read()


def texte_ecran(e):
    out = []
    for n in range(ROWS):
        b = bytes.fromhex(e["lignes"].get(str(n), "00" * COLS))
        out.append("%2d|%s|" % (n, "".join(chr(c & 0x7F) if 32 <= (c & 0x7F) < 127
                                            else ("#" if c & 0x80 else ".") for c in b)))
    return "\n".join(out)


def main(args):
    url = "http://localhost:8040"
    if "--demon" in args:
        i = args.index("--demon")
        url = args[i + 1].rstrip("/")
        del args[i:i + 2]
    if not args:
        print(__doc__)
        return 1
    cmd, args = args[0], args[1:]
    if cmd == "serve":
        port, h, lent = 2324, 8040, False
        if "--port" in args:
            port = int(args[args.index("--port") + 1])
        if "--http" in args:
            h = int(args[args.index("--http") + 1])
        lent = "--lent" in args
        return demon(port, h, lent)
    if cmd == "touches":
        lot = bytearray()
        for k in codes_touches(args[0] if args else ""):
            if k == "|" or k == -1:
                if lot:
                    http(url, "/touches", bytes(lot))
                    lot = bytearray()
                if k == "|":
                    time.sleep(3)
                else:
                    http(url, "/reset", b"")
            else:
                lot.append(k)
        if lot:
            http(url, "/touches", bytes(lot))
        return 0
    if cmd == "coller":
        http(url, "/coller", open(args[0], "rb").read())
        return 0
    if cmd == "ecran":
        print(texte_ecran(json.loads(http(url, "/ecran?depuis=0"))))
        return 0
    if cmd == "etat":
        print(http(url, "/ecran?depuis=0").decode())
        return 0
    if cmd == "attendre":
        cible = args[0]
        fin = time.time() + (float(args[1]) if len(args) > 1 else 30)
        while time.time() < fin:
            e = json.loads(http(url, "/ecran?depuis=0"))
            if cible in texte_ecran(e):
                return 0
            time.sleep(0.3)
        return 1
    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
