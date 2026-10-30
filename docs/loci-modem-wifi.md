# Relier un Raspberry Pi Pico W (modem WiFi) au LOCI

**État** : la liaison marche dans les deux sens (Oric, LOCI, Pico W, WiFi, Mac), avec le
firmware 0.3.98 du LOCI (`tools/loci-acia-diag/`, voir « Firmware du LOCI »).

But : donner à un vrai Oric un accès réseau (envoi et réception de fichiers) à travers le
LOCI et un modem WiFi USB, pour CP/A. Ce document décrit le matériel et sa préparation.
Côté CP/A, `TERM.COM` (terminal, `docs/manuel.md` « Terminal série ») et `XFER.COM`
(fichiers, « Transfert de fichiers ») existent ; le pilote série du BIOS est à faire.

## Principe

Le LOCI présente à l'Oric un circuit série 6551 (ACIA) émulé à l'adresse `$0380`, à
9600 bauds, relié à un modem USB branché sur son port. Le modem PicoWiFiModemUSB est un
Raspberry Pi Pico W qui se comporte comme un modem Hayes : on lui parle avec des commandes
AT et, au lieu de composer un numéro, il ouvre une connexion TCP en WiFi
(`ATDT-hôte:port`, le `-` coupant le mode telnet pour avoir des octets bruts ; `ATD` seul,
sans `T`, `P` ou `I`, répond `ERROR`).

## Matériel

- **Un Raspberry Pi Pico W** (la version WiFi du Pico, environ 7 €). La version de test
  du firmware vise le Pico W ; rien n'indique qu'elle fonctionne sur le Pico 2 W.
- **Un câble pour le relier au LOCI.** Le Pico W a une prise micro-USB, le LOCI une prise
  USB-C en mode hôte : il faut un câble USB-C mâle vers micro-USB mâle qui transporte
  les données (ou un adaptateur USB-C OTG et un câble micro-USB classique). Un câble de
  charge seule alimente le Pico (sa diode s'allume) mais le LOCI ne voit aucun modem :
  `$038C` reste à 0 dans `ACIADIAG`, l'état de l'ACIA reste `70` et les ordres de l'Oric
  (DTR, vitesse) ne sont pas appliqués.
- **Peut-être un hub USB.** Le LOCI n'a qu'un port USB. Si `cpa.dsk` est sur une clé USB,
  il faut un hub pour la clé et le Pico. La documentation du LOCI conseille un petit hub
  USB 2.0, plutôt ancien et simple : la plupart des hubs récents ne marchent pas avec lui.
  Essayé : un hub alimenté Anker refusé ; un hub **non alimenté** reconnaît la clé et le
  Pico (tout le courant passe alors par l'Oric : voir « Alimentation »).
- **Pour éviter le hub**, copier `cpa.dsk` dans la mémoire interne du LOCI (15 Mo) ; le
  Pico occupe alors seul le port USB.

## Alimentation

- Le LOCI se nourrit sur le port d'extension de l'Oric, et chaque appareil USB ajoute à la
  consommation. Bloc d'alimentation de l'Oric : au moins 9 V / 1 A.
- Avec un hub alimenté, le LOCI coupe par sécurité l'alimentation qu'il fournit au port
  d'extension : l'Oric doit avoir sa propre alimentation (cas normal).

- Sans hub alimenté, le LOCI, la clé et le Pico tirent leur courant du régulateur 5 V de
  l'Oric, qui dissipe en chaleur l'écart entre l'entrée et 5 V : un bloc de 12 V le fait
  nettement plus chauffer qu'un bloc de 9 V. Surveiller la chaleur près de l'entrée
  d'alimentation de l'Oric.

## Firmware du Pico

- **v0.1.0** (seule release publiée, `wifi_modem_v0.1.0.uf2` sous « Assets », liste
  repliée) : **ne garde pas les réglages**. `AT&W` gèle le Pico (interruption WiFi pendant
  l'écriture en flash) ; il faut débrancher, et rien n'est enregistré.
- Le code du dépôt (juin 2026, commit `c65fcd0`) corrige ce défaut, mais aucun `.uf2` n'est
  publié : le compiler (ci-dessous). Il ajoute `AT$SCAN` (réseaux WiFi visibles) et un
  redémarrage en mode BOOTSEL quand l'hôte ouvre le port USB à **1200 bauds**. Or le LOCI
  transmet au Pico la vitesse que l'Oric écrit dans le registre de contrôle de l'ACIA
  (`loci-firmware`, `src/mia/oric/acia.c`) : un programme Oric à 1200 bauds (Oricomms)
  ferait disparaître le modem. Pour le LOCI, compiler sans ce redémarrage : dans
  `src/usb_cdc.c`, vider `tud_cdc_line_coding_cb`. Le Pico ignore sinon la vitesse : sur
  l'USB, toutes marchent.
- Compiler (Linux ou Mac, avec `cmake`, `ninja` et `arm-none-eabi-gcc` et sa newlib) :

      git clone https://github.com/sodiumlb/PicoWiFiModemUSB.git
      cd PicoWiFiModemUSB && git submodule update --init
      (cd src/pico-sdk && git submodule update --init)
      (cd src/pico-extras && git submodule update --init)
      mkdir src/bld && cd src/bld && cmake -G Ninja .. && ninja    # -> wifi_modem.uf2

## Firmware du LOCI

- **0.3.98 « acia-diag »** (`tools/loci-acia-diag/`) : les sources de la 0.3.1 (dépôt
  `sodiumlb/loci-firmware`, branche `main`), la ROM du LOCI 0.3.0 recompilée et intégrée,
  et des registres de contrôle en lecture seule : motif `A5 5A 0F F0` en `$0384-$0387` et
  `$0344-$0347`, lectures de `$0381` vues (`$0388`), écritures dans `$0380-$0383` vues
  (`$0389`), derniers octets écrits en commande et contrôle (`$038A`, `$038B`), modem monté
  et DTR (`$038C`, bits 0 et 1), marque `$D1` (`$038D`). `CONFIG.SYS` garde son format. Mode
  d'emploi et lecture des résultats : `tools/loci-acia-diag/LISEZMOI.md`. Construit avec
  GCC 13 et newlib-nano : `printf` sans décimaux, la clé se décrit donc `1: MSC  GB General
  UDisk` (sans sa taille), dans le menu du LOCI comme pour CP/A (`docs/usb.md` § 2). Le
  montage d'une image de la mémoire interne (`0:`) y fige le LOCI : CP/A le refuse.
- **0.3.1 officielle** : `TERM /D` y lisait `A7 4C D0` (état, commande, contrôle), mais le
  Pico était alors relié par un câble sans données ; contre-essai à refaire avec le bon
  câble (`docs/etat.md` § 2 point 4).
- La branche de l'issue 17 du firmware (ACIA en `$0340` ou `$0380`, mars 2026) n'est pas
  finie : elle enregistre `CONFIG.SYS` avant que le système de fichiers soit monté et ne
  réapplique pas le réglage lu ; ne pas l'installer en l'état.

## Préparer le Pico, sur le Mac

1. **Installer le firmware.** Brancher le Pico sur le Mac en maintenant son bouton BOOTSEL :
   il apparaît comme un disque (RPI-RP2). Copier le `.uf2` dessus ; le Pico redémarre tout
   seul.
2. **Configurer le WiFi.** Rebranché normalement, le Pico est un port série :

       screen /dev/tty.usbmodem* 9600

   puis taper :

       AT$SSID=nom du réseau
       AT$PASS=mot de passe
       ATC1
       AT&W

   Le Pico se connecte alors au WiFi à chaque mise sous tension (WiFi 2,4 GHz seulement).
   `ATI` donne l'adresse IP et l'état de la connexion, `AT&V1` les réglages enregistrés,
   `AT?` la liste des commandes. Quitter `screen` : touche control (pas ⌘) et A, puis K,
   puis Y ; s'il reste bloqué, fermer la fenêtre et `killall screen` (sinon le port reste
   pris).
3. **Vérifier.** Sur le Mac, dans un autre terminal : `nc -l 2323`. Dans `screen` :
   `ATDT-IP_DU_MAC:2323` (adresse du Mac : `ipconfig getifaddr en0`). Ce qui est tapé d'un côté doit apparaître de l'autre. `+++`
   (une seconde de pause avant et après) revient au mode commande, `ATH` raccroche.

Réglages par défaut du modem : 9600 bauds, 8 bits, sans parité, 1 bit d'arrêt.
`ATDT[+=-]hôte[:port]` : `+` telnet simulé, `=` vrai telnet, `-` sans telnet ;
port 23 par défaut. `ATNETn` : 0 sans telnet, 1 vrai, 2 simulé.
Noms d'hôtes : le modem résout les noms par le DNS du réseau (`ATDT-ipinfo.io:80` :
CONNECT) ; pas les noms mDNS en `.local` (`NO CARRIER`). Numéros abrégés avec alias
(`AT&Zn=hôte:port,alias`, `ATDSn`, ou l'alias après `ATDT`), d'après la documentation
de PicoWiFiModem : `AT&Z0=...` répond OK mais l'entrée enregistrée ne change pas
(écriture en flash par `AT&W` ? elle gèle la v0.1.0) ; non résolu.

## Brancher le Pico sur le LOCI

- Le Pico configuré se branche sur le port USB du LOCI, directement ou par le hub.
- Le LOCI reconnaît les modems USB de ce type (CDC) et les présente à l'Oric comme le port
  série en `$0380` ; il règle le modem à 9600 bauds au branchement, puis à la vitesse que
  l'Oric écrit dans le registre de contrôle de l'ACIA.
- Aucun réglage dans le menu du LOCI : c'est automatique (le LOCI prend le premier appareil
  USB série qui se déclare modem). Le menu du LOCI voit la clé et le Pico par un hub non
  alimenté (constaté).

## Tester la chaîne

1. **Le LOCI et le modem** : `ACIADIAG.TAP` (`tools/loci-acia-diag/`) monté comme cassette,
   BASIC, `CLOAD""`. Attendu avec le Pico branché : marque `D1`, les deux motifs justes,
   modem `1`, ACIA avant `10 2 0`, 10 lectures et 2 écritures vues, `B 1E`, ACIA après
   `18 B 1E` (le modem a déjà répondu), modem `3`. Sous CP/A : `DEBUG`, `D 0380`.
2. **La chaîne entière** : `TERM /E` côté Oric, `nc -l 2323` côté Mac ; `AT` répond `OK`,
   puis `ATDT-IP_DU_MAC:2323` : ce qui est tapé d'un côté apparaît de l'autre. Essayé :
   ça passe dans les deux sens. Oricomms (terminal
Prestel des années 80) plante à la première touche sur ce montage : ne pas s'en servir.

L'ACIA du LOCI (`loci-firmware`, `src/mia/oric/acia.c`) : registres toujours présents en
`$0380-$0383` ; état : bit 3 reçu, bit 4 émetteur libre, bits 5 et 6 (DCD, DSR) à 1 tant
qu'aucun modem n'est monté ; rien n'est émis tant que DTR (bit 0 de la commande) est à 0 ;
réception par un tampon de 32 octets, rempli seulement s'il a de la place (le modem attend :
pas de perte si l'Oric tarde).
Accès : `LDA` / `STA` absolus seulement. Une écriture indexée (`STA (zp),Y`, `STA abs,X`,
`POKE` en BASIC) lit l'adresse visée avant de l'écrire : sur le registre de données, c'est un
octet reçu consommé (avertissement de l'auteur du LOCI, forum defence-force, sujet 2926).
Même sujet : sodiumlb affirme que les binaires publiés (0.3.1) marchent en `$0380` ; un autre
utilisateur y lit pourtant `$36`/`$76` (bus non piloté), cause non trouvée. Avec la 0.3.98 :
`70 02 00` au démarrage sans modem, `10 02 00` avec le Pico monté, puis `18 0B 1E` après le
réglage (voir « Firmware du LOCI » pour la 0.3.1).

## Côté CP/A

1. `TERM.COM` : fait (`docs/manuel.md`, « Terminal série »).
2. Pilote série dans le BIOS : entrées CP/M `PUNCH` / `READER` reliées à l'ACIA
   (adresse dans une variable : `$0380` sur LOCI, `$031C` dans Oricutron). À faire.
3. `XFER.COM` : envoi et réception de fichiers en XMODEM-CRC (blocs de 128 octets
   acquittés un par un), avec le serveur `tools/xfer_server.py` sur le Mac ou le Pi : fait
   (`docs/manuel.md`, « Transfert de fichiers » ; `tools/test_xfer.sh` dans Oricutron).
   TERM et XFER partagent la bibliothèque `progs/acia_inc.s` (port, réglage, lecture et
   écriture par scrutation), que le pilote du BIOS reprendra.

Débit : 9600 bauds, environ 1 Ko par seconde.

## Contrôle de flux

Aucun octet ne se perd quand l'Oric tarde à lire, sans RTS/CTS et sans rien côté Oric :

- LOCI (`loci-firmware`, `src/mia/oric/acia.c`) : il ne lit le modem USB que pour la place
  libre de son tampon de 32 octets ; tant que l'Oric ne lit pas, l'USB n'avance pas.
- Pico W (`PicoWiFiModemUSB`, `src/ser_cdc.c`) : `ser_putc` attend que l'USB accepte
  l'octet ; le tampon de réception TCP (`src/tcp_support.h`) ne rend la fenêtre à l'émetteur
  (`altcp_recved`) que s'il reste sous un segment : le Mac attend à son tour.

Les tampons sont donc dans le LOCI, le Pico et la pile TCP, pas dans l'Oric : le pilote série
de CP/A travaille par scrutation. Ce n'est vrai que du LOCI : un vrai 6551 (Oricutron en
`$031C`, carte série) n'a qu'un octet de réception et le perd si on tarde.

Fins de ligne : le modem, en mode commande, prend CR (ou LF) comme fin de commande ; `nc` sur
le Mac envoie LF seul et attend LF. TERM affiche CR, LF seul et CR LF comme un passage à la
ligne ; vers `nc`, `TERM /E /L` (RETURN envoie CR LF).

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
