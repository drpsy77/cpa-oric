#!/usr/bin/env python3
"""Prépare les fichiers de la passerelle qui publie l'Oric sur Internet
(docs/console-distance.md § 9.6) : tunnel WireGuard entre le VPS et la
machine du démon, Apache en lecture seule, services du démon et de la vitrine.

    tools/passerelle.py --vps NOM [--chemin /cpa/] [--port-wg 51820]
                        [--reseau 10.77.0] [--utilisateur pi]
                        [--depot /home/pi/cpa-oric] [--http 8040]
                        [--sortie logs/passerelle]

    --vps       nom (ou adresse) public du VPS, celui du certificat HTTPS
    --reseau    trois premiers nombres des adresses du tunnel : VPS .1,
                maison .2 (à changer s'il est déjà pris sur le VPS)
    --utilisateur, --depot : compte et dépôt CP/A sur la machine du démon

Écrit dans --sortie (logs/ n'est pas versionné : les clés n'y quittent pas
la machine) :
    vps/wg0.conf               -> /etc/wireguard/wg0.conf du VPS
    vps/cpa-oric.conf          -> à inclure dans le VirtualHost HTTPS d'Apache
    maison/wg0.conf            -> /etc/wireguard/wg0.conf de la machine du démon
    maison/cpa-remote.service  -> /etc/systemd/system/ (démon, spectateurs)
    maison/cpa-vitrine.service -> /etc/systemd/system/ (vitrine)
    LISEZMOI.txt               les commandes, dans l'ordre
Les clés (cles.json) sont gardées : relancer le script ne les change pas.
Clés WireGuard calculées ici (X25519, RFC 7748) : pas besoin de « wg genkey ».

Bibliothèque standard seulement.
"""
import base64
import json
import os
import secrets
import sys

P = 2 ** 255 - 19


def x25519(k, u):
    """Multiplication scalaire sur Curve25519 (RFC 7748 § 5)."""
    k = bytearray(k)
    k[0] &= 248
    k[31] &= 127
    k[31] |= 64
    k = int.from_bytes(k, "little")
    u = int.from_bytes(u, "little") & ((1 << 255) - 1)
    x1, x2, z2, x3, z3, swap = u, 1, 0, u, 1, 0
    for t in range(254, -1, -1):
        kt = (k >> t) & 1
        swap ^= kt
        if swap:
            x2, x3, z2, z3 = x3, x2, z3, z2
        swap = kt
        a, b = x2 + z2, x2 - z2
        aa, bb = a * a % P, b * b % P
        e = aa - bb
        c, d = x3 + z3, x3 - z3
        da, cb = d * a % P, c * b % P
        x3 = (da + cb) ** 2 % P
        z3 = x1 * (da - cb) ** 2 % P
        x2 = aa * bb % P
        z2 = e * (aa + 121665 * e) % P
    if swap:
        x2, z2 = x3, z3
    return (x2 * pow(z2, P - 2, P) % P).to_bytes(32, "little")


def b64(b):
    return base64.b64encode(b).decode()


def cle_privee():
    k = bytearray(secrets.token_bytes(32))
    k[0] &= 248                       # comme « wg genkey »
    k[31] = (k[31] & 127) | 64
    return bytes(k)


def publique(prive_b64):
    return b64(x25519(base64.b64decode(prive_b64), (9).to_bytes(32, "little")))


def verifier():
    """Vecteur de la RFC 7748 § 6.1 (clé d'Alice)."""
    a = bytes.fromhex("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
    return x25519(a, (9).to_bytes(32, "little")).hex() == \
        "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a"


def ecrire(chemin, texte, secret=False):
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    with open(chemin, "w", encoding="utf-8") as f:
        f.write(texte)
    if secret:
        os.chmod(chemin, 0o600)


def main(args):
    if not verifier():
        print("X25519 faux : arret")
        return 1
    ici = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    o = {"vps": None, "chemin": "/cpa/", "port-wg": "51820", "reseau": "10.77.0",
         "utilisateur": "pi", "depot": None, "http": "8040",
         "sortie": os.path.join(ici, "logs", "passerelle")}
    i = 0
    while i < len(args):
        nom = args[i][2:] if args[i].startswith("--") else None
        if nom not in o or i + 1 >= len(args):
            print(__doc__)
            return 1
        o[nom] = args[i + 1]
        i += 2
    if not o["vps"]:
        print(__doc__)
        return 1
    o["depot"] = o["depot"] or "/home/%s/cpa-oric" % o["utilisateur"]
    ch = "/" + o["chemin"].strip("/") + "/"
    vps_ip, maison_ip = o["reseau"] + ".1", o["reseau"] + ".2"
    out = o["sortie"]

    fc = os.path.join(out, "cles.json")
    if os.path.exists(fc):
        cles = json.load(open(fc))
    else:
        cles = {"vps": b64(cle_privee()), "maison": b64(cle_privee()),
                "partagee": b64(secrets.token_bytes(32))}
        ecrire(fc, json.dumps(cles, indent=1) + "\n", secret=True)

    ecrire(os.path.join(out, "vps", "wg0.conf"), """\
# WireGuard du VPS ({vps}) : attend l'appel de la maison
[Interface]
PrivateKey = {kv}
Address = {vip}/24
ListenPort = {port}

[Peer]
# machine du démon CP/A (la maison)
PublicKey = {pm}
PresharedKey = {psk}
AllowedIPs = {mip}/32
""".format(vps=o["vps"], kv=cles["vps"], vip=vps_ip, port=o["port-wg"],
           pm=publique(cles["maison"]), psk=cles["partagee"], mip=maison_ip), secret=True)

    ecrire(os.path.join(out, "maison", "wg0.conf"), """\
# WireGuard de la machine du démon CP/A : appelle le VPS (rien à ouvrir sur la box)
[Interface]
PrivateKey = {km}
Address = {mip}/24

[Peer]
# VPS {vps}
PublicKey = {pv}
PresharedKey = {psk}
Endpoint = {vps}:{port}
AllowedIPs = {vip}/32
PersistentKeepalive = 25
""".format(vps=o["vps"], km=cles["maison"], mip=maison_ip, pv=publique(cles["vps"]),
           psk=cles["partagee"], port=o["port-wg"], vip=vps_ip), secret=True)

    ecrire(os.path.join(out, "vps", "cpa-oric.conf"), """\
# CP/A : l'Oric en direct, lecture seule (docs/console-distance.md § 9.6).
# A inclure dans le <VirtualHost *:443> de {vps} :
#     Include /etc/apache2/cpa-oric.conf
# Modules : proxy, proxy_http.
RedirectMatch ^{sans}$ {ch}
<Location {ch}>
    ProxyPass http://{mip}:{http}/ timeout=30 retry=5
    ProxyPassReverse http://{mip}:{http}/
    # rien d'autre que regarder (le démon refuse aussi : --spectateurs)
    <LimitExcept GET HEAD>
        Require all denied
    </LimitExcept>
</Location>
<LocationMatch "^{ch}(journal|version)">
    Require all denied
</LocationMatch>
""".format(vps=o["vps"], sans=ch.rstrip("/"), ch=ch, mip=maison_ip, http=o["http"]))

    ecrire(os.path.join(out, "maison", "cpa-remote.service"), """\
[Unit]
Description=CP/A : console a distance (demon), spectateurs par le tunnel
After=network-online.target wg-quick@wg0.service
Wants=network-online.target

[Service]
User={u}
WorkingDirectory={d}
ExecStart=/usr/bin/python3 {d}/tools/remote.py serve --http {http} --spectateurs {vip}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
""".format(u=o["utilisateur"], d=o["depot"], http=o["http"], vip=vps_ip))

    ecrire(os.path.join(out, "maison", "cpa-vitrine.service"), """\
[Unit]
Description=CP/A : vitrine (demo tapee par le demon)
After=cpa-remote.service
Requires=cpa-remote.service

[Service]
User={u}
WorkingDirectory={d}
ExecStart=/usr/bin/python3 -u {d}/tools/vitrine.py --demon http://localhost:{http}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
""".format(u=o["utilisateur"], d=o["depot"], http=o["http"]))

    ecrire(os.path.join(out, "LISEZMOI.txt"), """\
Passerelle CP/A : https://{vps}{ch}
Fichiers de ce dossier ({out}) ; les .conf de WireGuard contiennent des cles :
ne pas les publier.

1. VPS ({vps}, Debian ou Ubuntu), en root :
     apt install wireguard-tools
     ip -4 addr | grep {reseau}.     # rien : le reseau du tunnel est libre
   copier vps/wg0.conf en /etc/wireguard/wg0.conf (chmod 600), puis :
     systemctl enable --now wg-quick@wg0
     ufw allow {port}/udp            # si ufw est actif ; sinon pare-feu de l'hebergeur
   copier vps/cpa-oric.conf en /etc/apache2/cpa-oric.conf, ajouter dans le
   <VirtualHost *:443> de {vps} la ligne
     Include /etc/apache2/cpa-oric.conf
   puis :
     a2enmod proxy proxy_http
     apachectl configtest && systemctl reload apache2

2. Machine du demon (Raspberry Pi OS, depot dans {d}) :
     sudo apt install wireguard-tools
   copier maison/wg0.conf en /etc/wireguard/wg0.conf (sudo, chmod 600), puis :
     sudo systemctl enable --now wg-quick@wg0
     ping -c 3 {vip}                  # le VPS repond par le tunnel
   copier maison/cpa-remote.service et maison/cpa-vitrine.service dans
   /etc/systemd/system/, arreter le demon lance a la main, puis :
     sudo systemctl daemon-reload
     sudo systemctl enable --now cpa-remote cpa-vitrine
     journalctl -u cpa-vitrine -f     # les scenes ; Ctrl-C pour sortir

3. Verifier, depuis le VPS :
     curl -s http://{mip}:{http}/ecran | head -c 120     # "lecture_seule": true
     curl -s -o /dev/null -w '%{{http_code}}\\n' -X POST http://{mip}:{http}/touches   # 403
   puis https://{vps}{ch} dans un navigateur : l'ecran, sans boutons.
   Depuis la maison, http://localhost:{http}/ garde le clavier ; la vitrine
   s'arrete 2 min des que quelqu'un tape.

Couper la publication : sudo systemctl stop wg-quick@wg0 (maison).
""".format(vps=o["vps"], ch=ch, out=out, reseau=o["reseau"], port=o["port-wg"],
           d=o["depot"], vip=vps_ip, mip=maison_ip, http=o["http"]))

    print("Passerelle preparee dans %s (LISEZMOI.txt)" % out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
