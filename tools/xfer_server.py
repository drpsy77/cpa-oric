#!/usr/bin/env python3
"""Serveur de fichiers pour XFER.COM (CP/A) : XMODEM-CRC sur TCP.

    python3 tools/xfer_server.py [--port 2323] [--dir DOSSIER]

L'Oric s'y connecte par le modem WiFi du LOCI (TERM, puis
ATDT-adresse:port, puis CTRL-Q ; dans Oricutron : ATDT127.0.0.1:port).
Le serveur attend des lignes de commande, terminées par CR ou LF :

    XFER GET nom [T]   l'Oric reçoit le fichier nom du dossier
    XFER PUT nom [T]   l'Oric envoie un fichier, écrit sous le nom nom

Réponse : « +OK » (le transfert XMODEM suit) ou un refus : « -A ... »
(fichier absent), « -N ... » (nom refusé), « -C ... » (commande
inconnue) ; XFER affiche son propre message, dans la langue de la
disquette. Le serveur est l'émetteur pour GET, le
récepteur pour PUT. Les ^Z ($1A) qui complètent le dernier bloc sont
retirés à la réception (même règle que STAT et EXPORT). Avec T : texte,
LF -> CR LF et tabulation -> espace vers l'Oric, CR LF -> LF vers le Mac.

Noms : sans chemin (ni « / » ni « .. ») ; GET cherche sans tenir compte
des majuscules ; PUT écrit le nom en minuscules s'il a été tapé tout en
majuscules (l'Oric démarre en majuscules), tel quel sinon, en remplaçant
un fichier du même nom. Un client à la fois ; une connexion sert autant de commandes
qu'on veut.
"""

import argparse
import os
import socket
import sys
import time

SOH, EOT, ACK, NAK, CAN = 0x01, 0x04, 0x06, 0x15, 0x18


def crc16(data):
    """CRC-16 de XMODEM (polynôme $1021, départ 0)."""
    crc = 0
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else (crc << 1)
            crc &= 0xFFFF
    return crc


class Link:
    """Lecture octet par octet avec délai, sur une socket."""

    def __init__(self, sock):
        self.sock = sock
        self.buf = b""

    def getb(self, timeout):
        if not self.buf:
            self.sock.settimeout(timeout)
            try:
                data = self.sock.recv(4096)
            except socket.timeout:
                return None
            if not data:
                raise ConnectionError("liaison coupée")
            self.buf = data
        b, self.buf = self.buf[0], self.buf[1:]
        return b

    def send(self, data):
        self.sock.sendall(bytes(data))

    def purge(self, quiet=1.0):
        while self.getb(quiet) is not None:
            pass

    def line(self):
        """Ligne terminée par CR ou LF (None : liaison coupée)."""
        out = bytearray()
        while True:
            b = self.getb(None)
            if b in (13, 10):
                if out:
                    return out.decode("ascii", "replace")
                continue
            if b >= 32:
                out.append(b)
            if len(out) > 200:
                out.clear()


def send_xmodem(link, data, log, faults=False):
    """Envoie data (complété par des ^Z) ; True si l'Oric a tout acquitté.
    faults (tests) : bloc 3 abîmé une fois, bloc 4 envoyé deux fois."""
    hurt = {3, 4} if faults else set()
    if len(data) % 128:
        data += b"\x1a" * (128 - len(data) % 128)
    if not data:
        data = b"\x1a" * 128
    mode = None
    t0 = time.time()
    while mode is None:
        b = link.getb(5)
        if b == ord("C"):
            mode = "crc"
        elif b == NAK:
            mode = "sum"
        elif b == CAN:
            log("annulé par l'Oric")
            return False
        elif time.time() - t0 > 60:
            log("l'Oric n'a rien demandé")
            return False
    nblocks = len(data) // 128
    i = 0
    errors = 0
    while i < nblocks:
        block = data[128 * i:128 * (i + 1)]
        num = (i + 1) & 0xFF
        pkt = bytes([SOH, num, 255 - num]) + block
        if mode == "crc":
            c = crc16(block)
            pkt += bytes([c >> 8, c & 0xFF])
        else:
            pkt += bytes([sum(block) & 0xFF])
        if i + 1 in hurt and i + 1 == 3:
            hurt.discard(3)
            log("faute : bloc 3 abime")
            pkt = pkt[:-1] + bytes([pkt[-1] ^ 0xFF])
        link.send(pkt)
        while True:
            b = link.getb(10)
            if b in (ACK, NAK, CAN, None):
                break
        if b == ACK:
            if i + 1 in hurt and i + 1 == 4:
                hurt.discard(4)                 # répété : l'Oric doit l'ignorer
                log("faute : bloc 4 repete")
                continue
            i += 1
            errors = 0
            continue
        if b == CAN:
            log("annulé par l'Oric")
            return False
        errors += 1
        if errors >= 10:
            link.send([CAN, CAN, CAN])
            log("trop d'erreurs")
            return False
    for _ in range(10):
        link.send([EOT])
        if link.getb(10) == ACK:
            return True
    return False


def recv_xmodem(link, log, faults=False):
    """Reçoit un fichier ; renvoie ses octets (avec les ^Z), None si échec.
    faults (tests) : bloc 2 refusé une fois (NAK), acquit du bloc 5 perdu
    une fois (l'Oric doit le renvoyer, reçu en double)."""
    hurt = {2, 5} if faults else set()
    out = bytearray()
    expected = 1
    errors = 0
    link.send(b"C")
    first = True
    while True:
        b = link.getb(3)
        if b is None:
            errors += 1
            if errors >= 10:
                link.send([CAN, CAN, CAN])
                log("l'Oric n'envoie rien")
                return None
            link.send(b"C" if first else bytes([NAK]))
            continue
        if b == EOT:
            link.send([ACK])
            return bytes(out)
        if b == CAN:
            log("annulé par l'Oric")
            return None
        if b != SOH:
            continue
        pkt = []
        for _ in range(132):
            c = link.getb(1)
            if c is None:
                break
            pkt.append(c)
        ok = (len(pkt) == 132 and pkt[0] ^ pkt[1] == 0xFF
              and crc16(pkt[2:130]) == (pkt[130] << 8 | pkt[131]))
        if not ok:
            link.purge()
            errors += 1
            if errors >= 10:
                link.send([CAN, CAN, CAN])
                log("trop d'erreurs")
                return None
            link.send([NAK])
            continue
        first = False
        if expected == 2 and 2 in hurt and pkt[0] == 2:
            hurt.discard(2)
            log("faute : bloc 2 refuse")
            link.send([NAK])
            continue
        if pkt[0] == expected & 0xFF:
            out += bytes(pkt[2:130])
            expected += 1
        elif pkt[0] != (expected - 1) & 0xFF:
            link.send([CAN, CAN, CAN])
            log("blocs désordonnés")
            return None
        errors = 0
        if expected == 6 and 5 in hurt:
            hurt.discard(5)
            log("faute : acquit du bloc 5 perdu")
            continue
        link.send([ACK])


def to_oric(data):
    """Texte du Mac vers l'Oric : LF -> CR LF, tabulation -> espace."""
    data = data.replace(b"\r\n", b"\n").replace(b"\t", b" ")
    return data.replace(b"\n", b"\r\n")


def from_oric(data):
    """Texte de l'Oric vers le Mac : CR LF -> LF."""
    return data.replace(b"\r\n", b"\n")


def safe_name(name):
    return name and "/" not in name and "\\" not in name and name not in (".", "..")


def find(folder, name):
    """Nom réel dans folder, sans tenir compte des majuscules."""
    if os.path.isfile(os.path.join(folder, name)):
        return name
    for f in os.listdir(folder):
        if f.lower() == name.lower() and os.path.isfile(os.path.join(folder, f)):
            return f
    return None


def serve(conn, folder, log, faults=False):
    link = Link(conn)
    link.send(b"XFER : serveur CP/A pret\r\n")
    while True:
        words = link.line().split()
        if len(words) < 3 or words[0].upper() != "XFER":
            continue
        cmd, name = words[1].upper(), words[2]
        text = len(words) > 3 and words[3].upper() == "T"
        if not safe_name(name):
            link.send(b"-N nom refuse\r\n")
            continue
        if cmd == "GET":
            real = find(folder, name)
            if real is None:
                link.send(b"-A fichier absent\r\n")
                log("GET %s : absent" % name)
                continue
            with open(os.path.join(folder, real), "rb") as f:
                data = f.read()
            if text:
                data = to_oric(data)
            link.send(b"+OK\r\n")
            ok = send_xmodem(link, data, log, faults)
            log("GET %s%s : %d octets, %s" % (real, " (texte)" if text else "",
                                               len(data), "fait" if ok else "échec"))
        elif cmd == "PUT":
            if name == name.upper():        # tapé en majuscules : minuscules
                name = name.lower()
            link.send(b"+OK\r\n")
            data = recv_xmodem(link, log, faults)
            if data is None:
                log("PUT %s : échec" % name)
                continue
            data = data.rstrip(b"\x1a")
            if text:
                data = from_oric(data)
            with open(os.path.join(folder, name), "wb") as f:
                f.write(data)
            log("PUT %s%s : %d octets, fait" % (name, " (texte)" if text else "",
                                                 len(data)))
        else:
            link.send(b"-C commande inconnue\r\n")


def main():
    ap = argparse.ArgumentParser(description="Serveur de fichiers XMODEM pour XFER.COM")
    ap.add_argument("--port", type=int, default=2323)
    ap.add_argument("--dir", default=".", help="dossier servi (défaut : courant)")
    ap.add_argument("--fautes", action="store_true",
                    help="tests : erreurs simulées (bloc abîmé, répété, refusé, acquit perdu)")
    ap.add_argument("--once", action="store_true",
                    help="s'arrête à la fin de la première connexion (tests)")
    args = ap.parse_args()
    folder = os.path.abspath(args.dir)

    def log(msg):
        print(msg, flush=True)

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("", args.port))
    srv.listen(1)
    log("XFER : port %d, dossier %s" % (args.port, folder))
    while True:
        conn, addr = srv.accept()
        log("connexion de %s" % addr[0])
        try:
            serve(conn, folder, log, args.fautes)
        except (ConnectionError, OSError) as e:
            log("fin de la connexion (%s)" % e)
        finally:
            conn.close()
        if args.once:
            break


if __name__ == "__main__":
    sys.exit(main())
