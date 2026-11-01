#!/usr/bin/env python3
"""Console à distance de CP/A : le démon, et sa ligne de commande.

L'Oric appelle le démon par son modem (REMOTE hote, port 2324) ; le démon
tient une copie de l'écran de l'Oric, la met à jour en comparant des totaux
(docs/console-distance.md § 3, 4), et sert une interface HTTP locale (§ 9.1)
à la fenêtre tkinter (tools/remote_tk.py), à la page web et à la ligne de
commande ci-dessous.

    remote.py serve [--port 2324] [--http 8040] [--lent] [--log FICHIER]
        le démon ; --lent : un octet toutes les 25 ms vers l'Oric ; journal
        dans logs/remote.log du dépôt (par défaut ; 1 Mo, trois anciens
        gardés) : version, commit, paramètres, appels, chaque cycle qui
        change l'écran (durées), attentes dépassées, trames refusées, et un
        bilan par minute. Aussi lisible par HTTP : /journal?n=200, /version
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
import logging
import logging.handlers
import os
import platform
import subprocess
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

VERSION = "2026-11-01.4"        # changée à chaque modification du démon
COLS, ROWS = 40, 28
RP_REQ, RP_KEY, RP_FRM = 0xFD, 0xFE, 0xFF
LONGUEUR = {ord("S"): 60, ord("L"): 41}
LOT = 1024              # touches envoyées d'un coup au plus (texte collé)
PAR_TOUCHE = 0.1        # délai de réponse en plus par touche envoyée : la
                        # demande attend que le programme les ait lues
REPOS = 0.5             # cycle au repos
PERDUE = 5.0            # sans trame valide : liaison perdue
DELAI = 3.0             # attente d'une réponse avant de la redemander : le
                        # modem WiFi retient parfois l'envoi plus d'une seconde,
                        # et une demande répétée trop tôt fait recommencer la
                        # trame en cours sur l'Oric (elle la remplace)
ECHECS_SUITE = 3        # suites sans réponse avant de demander ligne par ligne
SUITE = 3               # à partir de 3 lignes changées (et au moins un quart
                        # de celles qui suivent la première) : une seule
                        # demande pour les lignes de la première à la 27


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
        self.stats = {}                 # mesures de la liaison (diagnostic)
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
                    "stats": self.stats, "lignes": lig}


class Liaison:
    """Une connexion de l'Oric : demandes, trames, touches."""

    def __init__(self, sock, ecran, envois, lent, journal):
        self.sock = sock
        self.ecran = ecran
        # diagnostic, lu dans /ecran : trames reçues, refusées (longueur ou
        # total faux : octet perdu), attentes dépassées par type, octets reçus,
        # dernière suite de lignes (lignes reçues, durée en s), cycles
        self.st = ecran.stats
        self.st.clear()
        self.st.update(trames=0, refusees=0, attentes={"S": 0, "L": 0, "suite": 0},
                       octets=0, suite=True, derniere_suite=None, cycles=0,
                       debut=round(time.time()))
        self.envois = envois
        self.lent = lent
        self.log = journal
        self.buf = bytearray()
        self.fini = False
        self.t_trame = time.time()
        self.cy = 0
        self.t_bilan = time.time()
        self.plage = True               # le pilote sait envoyer une suite de lignes
        self.echecs_suite = 0

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
            if hasattr(socket, "TCP_QUICKACK"):     # Linux : acquitter tout de
                self.sock.setsockopt(socket.IPPROTO_TCP,  # suite (sinon le modem,
                                     socket.TCP_QUICKACK, 1)  # qui attend l'acquit,
                                                      # retient ses envois)
        except socket.timeout:
            return
        if not d:
            raise ConnectionError("liaison coupée par l'Oric")
        self.buf += d
        self.st["octets"] += len(d)

    def trame(self, attendu, n=None, delai=DELAI):
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
                    self.st["refusees"] += 1
                    continue
                if len(self.buf) < lg + 4:
                    break
                donnees = bytes(self.buf[3:3 + lg])
                if (typ + lg + sum(donnees)) & 0xFF != self.buf[3 + lg]:
                    self.log("trame %s refusée (total faux) : %s..." % (
                        chr(typ), bytes(self.buf[:12]).hex()))
                    del self.buf[:1]
                    self.st["refusees"] += 1
                    continue
                del self.buf[:lg + 4]
                self.st["trames"] += 1
                self.t_trame = time.time()
                if typ == attendu and (n is None or donnees[0] == n):
                    return donnees
            reste = fin - time.time()
            if reste <= 0:
                return None
            self._lire(reste)

    def demande(self, msg, typ, n=None, essais=3, delai=DELAI):
        for _ in range(essais):
            self.envoyer(msg)
            d = self.trame(typ, n, delai)
            if d is not None:
                return d
            self.st["attentes"][chr(typ)] += 1
            self.log("attente dépassée : %s%s (%.1f s), %d octets en attente" % (
                chr(typ), "" if n is None else " %d" % n, delai, len(self.buf)))
            if time.time() - self.t_trame > PERDUE + delai:
                if self.ecran.liaison != "perdue":
                    self.log("liaison perdue : pas de trame depuis %.1f s"
                             % (time.time() - self.t_trame))
                self.ecran.poser(liaison="perdue")
        return None

    def suite(self, n):
        """Lignes n à 27 en une demande ($FD "L" n+$80) : une trame L chacune,
        sans aller-retour entre elles. Un pilote qui ne le sait pas ne répond
        rien : on revient aux demandes ligne par ligne."""
        self.envoyer([RP_REQ, ord("L"), n | 0x80])
        recu = 0
        t0 = time.time()
        while True:
            d = self.trame(ord("L"), None, DELAI)
            if d is None or d[0] < n:
                self.st["attentes"]["suite"] += 1
                break
            self.ecran.ligne(d[0], d[1:])
            recu += 1
            if d[0] == ROWS - 1:
                break
        self.st["derniere_suite"] = [n, recu, round(time.time() - t0, 2)]
        self.log("suite L %d+ : %d lignes en %.2f s" % (n, recu, time.time() - t0))
        self.echecs_suite = 0 if recu else self.echecs_suite + 1
        if self.echecs_suite >= ECHECS_SUITE:
            self.plage = False
            self.st["suite"] = False
            self.log("pilote sans suite de lignes : une demande par ligne")

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
        if len(lot) > 8:
            self.log("touches : %d envoyées d'un coup" % (len(lot) // 2))
        return len(lot) // 2

    # --- boucle ----------------------------------------------------------
    def boucle(self):
        attente = 0
        while not self.fini:
            nt = self.touches(attente)
            t0 = time.time()
            if 0 < nt <= 4:
                self.ligne(self.cy)        # écho rapide : la ligne du curseur
            t1 = time.time()
            s = self.demande([RP_REQ, ord("S")], ord("S"),
                             delai=DELAI + (PAR_TOUCHE * nt if nt > 4 else 0))
            t2 = time.time()
            if s is None:
                attente = 0
                continue
            self.ecran.poser(liaison="active")
            mode, cx, cy, actif = s[0], s[1], s[2], bool(s[3])
            self.cy = cy if cy < ROWS else 0
            self.ecran.poser(mode=mode, curseur=[cx, cy, actif])
            changees = []
            if mode & 0x7F != 2:
                debut = 16 if mode & 0x7F == 1 else 0   # SPLIT : lignes de texte
                changees = [n for n in range(debut, ROWS)
                            if fletcher(self.ecran.lignes[n]) != (s[4 + 2 * n], s[5 + 2 * n])]
            change = bool(changees)
            if (len(changees) >= SUITE and self.plage
                    and ROWS - changees[0] <= 4 * len(changees)):
                self.suite(changees[0])
                facon = "suite"
            else:
                for n in changees:
                    if not self.ligne(n):
                        break
                facon = "ligne par ligne"
            self.ecran.cycle_fait()
            self.st["cycles"] += 1
            if change or nt:
                self.log("cycle : %s écho %.2f s, S %.2f s, %d lignes %s %.2f s (mode %d)" % (
                    "%d touches," % nt if nt else "", t1 - t0, t2 - t1, len(changees),
                    facon, time.time() - t2, mode))
            if time.time() - self.t_bilan > 60:
                self.t_bilan = time.time()
                self.log("bilan : %s" % json.dumps(self.st))
            attente = 0 if change else REPOS


def commit_git():
    """Commit du dépôt du démon, « modifié » si remote.py diffère du commit."""
    ici = os.path.dirname(os.path.abspath(__file__))
    try:
        c = subprocess.run(["git", "-C", ici, "log", "-1", "--format=%h %ci %s"],
                           capture_output=True, text=True, timeout=5).stdout.strip()
        m = subprocess.run(["git", "-C", ici, "status", "--porcelain", "remote.py"],
                           capture_output=True, text=True, timeout=5).stdout.strip()
        return (c or "?") + (" (remote.py modifié)" if m else "")
    except (OSError, subprocess.SubprocessError):
        return "? (git absent)"


def demon(port, http, lent, fichier=None):
    ecran = Ecran()
    envois = queue.Queue()
    ici = os.path.dirname(os.path.abspath(__file__))
    fichier = fichier or os.path.join(os.path.dirname(ici), "logs", "remote.log")
    os.makedirs(os.path.dirname(os.path.abspath(fichier)), exist_ok=True)
    jl = logging.getLogger("remote")
    jl.setLevel(logging.INFO)
    f = logging.handlers.RotatingFileHandler(fichier, maxBytes=1_000_000, backupCount=3,
                                             encoding="utf-8")
    f.setFormatter(logging.Formatter("%(asctime)s %(message)s"))
    jl.addHandler(f)
    e = logging.StreamHandler(sys.stdout)
    e.setFormatter(logging.Formatter("%(asctime)s %(message)s", "%H:%M:%S"))
    jl.addHandler(e)

    def journal(m):
        jl.info(m)

    infos = {"version": VERSION, "commit": commit_git(), "python": platform.python_version(),
             "machine": "%s (%s)" % (platform.node(), platform.platform()),
             "pid": os.getpid(), "arguments": sys.argv[1:], "journal": os.path.abspath(fichier),
             "parametres": {"port": port, "http": http, "lent": lent, "LOT": LOT,
                            "PAR_TOUCHE": PAR_TOUCHE, "REPOS": REPOS, "PERDUE": PERDUE, "DELAI": DELAI, "ECHECS_SUITE": ECHECS_SUITE,
                            "SUITE": SUITE}}
    ecran.infos = infos
    journal("=== démarrage : %s" % json.dumps(infos, ensure_ascii=False))

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
            journal("appel de %s:%d" % addr)
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
            elif u.path == "/version":
                self._rep(200, json.dumps(ecran.infos, ensure_ascii=False).encode())
            elif u.path == "/journal":
                n = int(q.get("n", ["200"])[0])
                try:
                    with open(infos["journal"], encoding="utf-8") as fj:
                        t = "".join(fj.readlines()[-n:])
                except OSError as err:
                    t = "journal illisible : %s\n" % err
                self._rep(200, t.encode(), "text/plain; charset=utf-8")
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
        fichier = args[args.index("--log") + 1] if "--log" in args else None
        return demon(port, h, lent, fichier)
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
