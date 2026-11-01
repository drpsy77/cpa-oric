# Firmware du modem WiFi (Pico W) pour CP/A

`wifi_modem-cpa.uf2` : PicoWiFiModemUSB (https://github.com/sodiumlb/PicoWiFiModemUSB),
commit `c65fcd0`, avec `picowifimodem-cpa.patch` :

- **Nagle gardé** (`altcp_nagle_disable` retiré, `src/tcp_support.h`). Le LOCI passe au
  Pico les octets de l'Oric un à un par l'USB ; sans Nagle, le Pico envoie un paquet WiFi
  pour chaque poignée d'octets, sa file d'envoi se remplit, il cesse de lire l'USB, et
  l'Oric attend ; une perte sur le WiFi coûte un renvoi au bout d'une à quelques
  secondes. Avec Nagle, les octets qui arrivent pendant qu'un paquet attend son acquit
  partent ensemble dans le suivant. Le démon `tools/remote.py` acquitte tout de suite
  (`TCP_QUICKACK`), ce qui garde l'attente courte. Vise la console à distance et
  l'envoi par XFER.
- **Pas de redémarrage en mode BOOTSEL à 1200 bauds** (`tud_cdc_line_coding_cb` vidé,
  `src/usb_cdc.c`) : le LOCI transmet au Pico la vitesse que l'Oric écrit dans l'ACIA
  (`docs/loci-modem-wifi.md`, « Firmware du Pico »).

Installer : brancher le Pico sur le Mac en maintenant BOOTSEL, copier le `.uf2` sur le
disque RPI-RP2. Les réglages (`AT$SSID`, `AT$PASS`) sont en principe gardés ; sinon, les
refaire (`docs/loci-modem-wifi.md`, « Préparer le Pico »).

Refaire le `.uf2` (Linux ; paquets `gcc-arm-none-eabi`, `libnewlib-arm-none-eabi`,
`libstdc++-arm-none-eabi-newlib`, `cmake`, `ninja-build`) :

    git clone https://github.com/sodiumlb/PicoWiFiModemUSB.git && cd PicoWiFiModemUSB
    git checkout c65fcd0 && git submodule update --init
    (cd src/pico-sdk && git submodule update --init)
    (cd src/pico-extras && git submodule update --init)
    git apply ../cpa-oric/tools/pico-modem/picowifimodem-cpa.patch
    mkdir src/bld && cd src/bld && cmake -G Ninja .. && ninja    # -> wifi_modem.uf2
