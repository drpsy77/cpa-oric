# Relier un Raspberry Pi Pico W (modem WiFi) au LOCI

But : donner à un vrai Oric un accès réseau (envoi et réception de fichiers) à travers le
LOCI et un modem WiFi USB, pour CP/A. Ce document décrit le matériel et sa préparation ;
rien n'est encore codé côté CP/A.

## Principe

Le LOCI présente à l'Oric un circuit série 6551 (ACIA) émulé à l'adresse `$0380`, à
9600 bauds, relié à un modem USB branché sur son port. Le modem PicoWiFiModemUSB est un
Raspberry Pi Pico W qui se comporte comme un modem Hayes : on lui parle avec des commandes
AT et, au lieu de composer un numéro, il ouvre une connexion TCP en WiFi
(`ATD-hôte:port`, le `-` coupant le mode telnet pour avoir des octets bruts).

## Matériel

- **Un Raspberry Pi Pico W** (la version WiFi du Pico, environ 7 €). La version de test
  du firmware vise le Pico W ; rien n'indique qu'elle fonctionne sur le Pico 2 W.
- **Un câble pour le relier au LOCI.** Le Pico W a une prise micro-USB, le LOCI une prise
  USB-C en mode hôte : il faut un câble USB-C mâle vers micro-USB mâle qui transporte
  les données (ou un adaptateur USB-C OTG et un câble micro-USB classique).
- **Peut-être un hub USB.** Le LOCI n'a qu'un port USB. Si `cpa.dsk` est sur une clé USB,
  il faut un hub pour la clé et le Pico. La documentation du LOCI conseille un petit hub
  USB 2.0 alimenté, plutôt ancien et simple : la plupart des hubs récents ne marchent
  pas avec lui.
- **Pour éviter le hub**, copier `cpa.dsk` dans la mémoire interne du LOCI (15 Mo) ; le
  Pico occupe alors seul le port USB.

## Alimentation

- Le LOCI se nourrit sur le port d'extension de l'Oric, et chaque appareil USB ajoute à la
  consommation. Bloc d'alimentation de l'Oric : au moins 9 V / 1 A.
- Avec un hub alimenté, le LOCI coupe par sécurité l'alimentation qu'il fournit au port
  d'extension : l'Oric doit avoir sa propre alimentation (cas normal).

## Préparer le Pico, sur le Mac

1. **Installer le firmware.** Télécharger le `.uf2` de la version v0.1.0 (version de test,
   « pour tester avec le LOCI et le terminal Oricomms ») sur la page des releases de
   PicoWiFiModemUSB. Brancher le Pico sur le Mac en maintenant son bouton BOOTSEL : il
   apparaît comme un disque. Copier le `.uf2` dessus ; le Pico redémarre tout seul.
2. **Configurer le WiFi.** Rebranché normalement, le Pico est un port série :

       screen /dev/tty.usbmodem* 9600

   puis taper :

       AT$SSID=nom du réseau
       AT$PASS=mot de passe
       ATC1
       AT&W

   Le Pico se connecte alors au WiFi à chaque mise sous tension. `ATI` donne l'adresse IP
   et l'état de la connexion, `AT?` la liste des commandes. Quitter `screen` : Ctrl-A
   puis K.
3. **Vérifier.** Sur le Mac, dans un autre terminal : `nc -l 2323`. Dans `screen` :
   `ATD-IP_DU_MAC:2323`. Ce qui est tapé d'un côté doit apparaître de l'autre. `+++`
   (une seconde de pause avant et après) revient au mode commande, `ATH` raccroche.

Réglages par défaut du modem : 9600 bauds, 8 bits, sans parité, 1 bit d'arrêt.
`ATDT[+=-]hôte[:port]` : `+` telnet simulé, `=` vrai telnet, `-` sans telnet ;
port 23 par défaut. `ATNETn` : 0 sans telnet, 1 vrai, 2 simulé.

## Brancher le Pico sur le LOCI

- Le Pico configuré se branche sur le port USB du LOCI, directement ou par le hub.
- Le LOCI reconnaît les modems USB de ce type (CDC) et les présente à l'Oric comme le port
  série en `$0380`, à 9600 bauds.
- Aucun réglage n'est documenté dans le menu du LOCI ; cela semble automatique (non
  vérifié). Vérifier que le modem y apparaît et que le firmware du LOCI est récent.

## Tester avant de coder côté CP/A

Avec le terminal Oricomms (cité dans la note de version du firmware) côté Oric et
`nc -l 2323` côté Mac, on vérifie toute la chaîne : Oric, LOCI, Pico, WiFi, Mac. Si les
caractères passent dans les deux sens, le pilote série et le transfert XMODEM de CP/A
n'auront plus d'inconnue matérielle.

## Ce qui est prévu côté CP/A (non commencé)

1. Pilote série dans le BIOS : entrées CP/M `PUNCH` / `READER` reliées à l'ACIA
   (adresse dans une variable : `$0380` sur LOCI, `$031C` dans Oricutron).
2. `XFER.COM` : envoi et réception de fichiers en XMODEM (paquets de 128 octets acquittés
   un par un, ce qui supporte le tampon de 32 octets du LOCI et les accès disque), avec un
   script `tools/xfer_server.py` côté Mac.
3. `TERM.COM` : petit terminal pour parler au modem et aux serveurs.

Débit : 9600 bauds, environ 1 Ko par seconde.

Autre piste : le LOCI expose aussi une interface (registres en `$03A0`) pour lire et écrire
des fichiers ordinaires sur sa clé USB ; une commande CP/A pourrait exporter un fichier
vers la clé sans passer par `mkdisk.py`. En attendant, la clé ou la carte du LOCI contient
`cpa.dsk`, d'où `python3 tools/mkdisk.py get cpa.dsk LETTRE.TXT lettre.txt` extrait un
fichier sur le Mac.

## Sources

- PicoWiFiModemUSB : https://github.com/sodiumlb/PicoWiFiModemUSB
- LOCI User Manual : https://github.com/sodiumlb/loci-hardware/wiki/LOCI-User-Manual
- LOCI Mode d'emploi : https://github.com/sodiumlb/loci-hardware/wiki/LOCI-Mode-d'emploi
- ProphetOric (LOCI + PicoWiFiModemUSB, ACIA en $0380) : https://github.com/benedictemarty/ProphetOric
- Phosphoric (émulateur avec LOCI et WiFi) : https://github.com/benedictemarty/Phosphoric
- Forum defence-force, fil LOCI : https://forum.defence-force.org/viewtopic.php?t=2593&start=885
