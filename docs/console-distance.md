# Pilote série et console à distance (spécification de travail)

But : un Mac (ou le Pi) **tape et lit à la place du clavier et de l'écran** d'un vrai Oric,
par le modem WiFi du LOCI (`docs/loci-modem-wifi.md`). Usages : piloter les essais sur le
vrai Oric comme `tools/run_test.sh` le fait dans Oricutron, coller un texte dans EDIT,
travailler sur l'Oric depuis la fenêtre du Mac ou le navigateur d'un téléphone. La
console à distance doit survivre aux programmes : elle est dans le BIOS.

Rien n'est codé côté Oric ni dans le démon. Côté client, la fenêtre tkinter, son rendu
de l'écran et un faux démon d'essai sont faits (§ 9.2, § 9.3). Ce document suit le plan d'une spécification (`architecture.md` § 7) :
ce qui est décidé, puis les questions ouvertes ; il deviendra la référence une fois livré.
Le travail commence par le fichier `HOSTS` et l'appel du modem par les programmes (§ 8),
dont TERM, XFER et REMOTE se servent.

## 1. Principe

- **Côté Oric, un pilote sans état** : il reçoit des touches, qu'il range dans le tampon
  du clavier comme si on les avait tapées, et répond à des demandes du Mac sur l'écran
  (totaux de contrôle des 28 lignes, puis les lignes demandées). Il n'envoie **rien** sans
  demande : un Mac disparu ne fait rien partir vers le modem.
- **Côté Mac, un démon** (`tools/remote.py`) tient la liaison avec l'Oric, garde une copie
  de l'écran et la tient à jour en comparant les totaux. Les fenêtres (page web locale,
  fenêtre tkinter sur le petit écran d'un Raspberry Pi Zero), les scripts d'essai et la
  ligne de commande lui parlent par la même interface locale (§ 9.1) ; ils peuvent
  s'arrêter et repartir sans couper l'Oric.
- **Tout le mode texte est vu**, quel que soit le programme : EDIT, CMDER, HEX, les menus
  et la ligne d'état écrivent directement dans `SCREEN` ; le pilote lit l'écran lui-même.
  Pas le HIRES plein écran ; en SPLIT, seules les lignes de texte (16 à 27).
- **Le service tourne sous l'IRQ de 50 Hz** : il marche pendant un calcul, pendant ASM ou
  LOGO, avec un programme qui ne lit pas le clavier par le BDOS. Il s'arrête quand les
  interruptions sont coupées (accès disque) : le LOCI, le Pico et TCP gardent ce qui arrive
  (`loci-modem-wifi.md`, « Contrôle de flux ») ; rien n'est perdu.
- **Le clavier de l'Oric reste actif** : les deux sources remplissent le même tampon.

## 2. Ligne et réglages

- Port : celui de `acia_inc.s` (LOCI `$0380`, Oricutron `$031C`), 9600 bauds 8N1, DTR,
  sans interruption de l'ACIA, accès par `LDA` / `STA` absolus seulement. Les trois
  routines de registre du pilote (`LDA $0381` / `LDA $0380` / `STA $0380`, suivies de
  `RTS`) sont dans la RAM overlay ; leur octet bas est posé par la fonction 117 (§ 6).
- Appel : **l'Oric appelle le Mac** (`ATDT-hôte:port`, nom pris dans `HOSTS`, § 8). Le
  Mac ne peut pas réveiller l'Oric : il faudrait des travaux dans le firmware du LOCI.
  Port du démon **2324** (2323 reste à `xfer_server.py`). Dans Oricutron, `serial =
  'modem'` et `ATDT127.0.0.1:2324`, comme `tools/test_xfer.sh`.

## 3. Qui mène

Schéma animé, scénarios et les deux écrans côte à côte : `docs/console-distance.html`
(à ouvrir dans un navigateur).

| Quoi | Qui décide | Quand |
|---|---|---|
| ouvrir, fermer la liaison | l'Oric (`REMOTE`, `REMOTE OFF`) | à la main ou dans `AUTO.BAT` |
| touches du Mac | le Mac les envoie ; l'Oric les range s'il a de la place | à tout moment |
| touches de l'Oric | restent sur l'Oric ; le Mac les voit à l'écran au cycle suivant | à tout moment |
| écho d'une touche du Mac | **le Mac** demande la ligne du curseur (`L cy`) | dès que la touche est partie (écho rapide, ci-dessous) |
| rafraîchir l'écran | **le Mac** demande (`S`, puis `L n`) ; l'Oric répond | toutes les 0,5 s ; juste après l'écho rapide ; tout de suite tant qu'un cycle trouve des lignes changées |
| démarrage à chaud | le Mac (`$FD 'B'`) ou le bouton RESET | à la demande |

La liaison TCP reste ouverte dans les deux sens tant que la console est active ; l'Oric
n'y écrit qu'en réponse. **C'est le Mac qui trouve les lignes changées** : il calcule les
totaux de sa propre copie et les compare à ceux que l'Oric renvoie. Boucle du démon :

    si des touches attendent :
        les envoyer ($FE k pour chacune)
        écho rapide : envoyer $FD 'L' cy (ligne du curseur, d'après la dernière
            trame S) ; copie[cy] = les 40 octets reçus
    envoyer $FD 'S' ; attendre la trame S (1 s au plus, sinon la redemander)
    pour chaque ligne n dont le total reçu diffère de fletcher(copie[n]) :
        envoyer $FD 'L' n ; attendre la trame L ; copie[n] = ses 40 octets
    une ligne a changé : recommencer tout de suite ;
    sinon attendre 0,5 s, ou la prochaine touche

**Pas d'écho local** : une touche tapée sur le Mac ne s'affiche pas sur le Mac. Elle part
à l'Oric, et c'est le programme de l'Oric qui décide quoi afficher (dans CMDER, une flèche
déplace la sélection ; dans EDIT, une touche insère, efface ou fait défiler). Le Mac montre
ensuite ce que l'Oric a affiché, comme un terminal à distance (telnet, ssh). Le Mac n'a
donc pas à savoir d'où vient un changement : touche du Mac ou du clavier de l'Oric, il voit
l'écran de l'Oric.

**Écho rapide** : juste après une touche, le Mac demande d'abord la ligne du curseur
(presque toujours celle qui change), puis fait le cycle complet pour le reste (défilement,
menus, ligne d'état). Délai estimé entre la frappe et son affichage : 0,1 à 0,15 s, au lieu
de 0,3 à 0,4 s avec le cycle seul. Coût côté Oric : nul.

Fidélité : la copie contient les octets exacts de l'écran, attributs compris ; la page
les dessine avec la police de CP/A et les règles de l'ULA. Un état plus bref qu'un cycle
n'est pas vu (seul l'état final arrive).

## 4. Protocole

Un seul flux d'octets dans chaque sens. Les messages du modem (`CONNECT`, `NO CARRIER`,
`OK`) passent dans le même flux : ils doivent être ignorés des deux côtés.

### Mac vers Oric : tout message commence par un octet `$FD` ou `$FE`

Le modem n'envoie que de l'ASCII (< `$80`) : un octet qui ne suit pas un préfixe est
ignoré. Ainsi `NO CARRIER` n'arrive jamais à l'Oric comme une frappe.

| Message | Effet |
|---|---|
| `$FE k` | touche de code `k` (0-255), rangée dans le tampon du clavier ; codes du contrat (`architecture.md` § 2, « Codes du clavier » ; FUNCT = `$80`) |
| `$FD 'S'` | demande des totaux (réponse `S`) |
| `$FD 'L' n` | demande de la ligne `n` (0-27) (réponse `L`) |
| `$FD 'B'` | démarrage à chaud, comme le bouton RESET (essais : programme bloqué qui garde les interruptions) |

- Une touche n'est lue de l'ACIA que s'il y a de la place dans le tampon du clavier
  (16 octets) : sinon le pilote laisse l'octet au LOCI. Un texte collé de plusieurs Ko
  arrive donc sans perte, au rythme où le programme lit (EDIT, la ligne de commande).
- Une demande arrivée pendant le service d'une autre la remplace (le Mac se
  resynchronise ainsi). Le Mac n'en a qu'une en cours à la fois.

### Oric vers Mac : trames, seulement en réponse

    $FF  type  longueur  données (longueur octets)  total

`total` = somme sur 8 bits de `type`, `longueur` et des données. Le Mac cherche `$FF`,
vérifie la longueur et le total, et jette tout le reste (messages du modem, trame coupée) ;
une trame refusée est redemandée.

| Type | Données |
|---|---|
| `'S'` (60 octets) | mode (0 texte, 1 SPLIT, 2 écran au programme : HIRES plein, bit 7 = `SCR_PROG`), colonne et ligne du curseur, curseur actif, puis 28 totaux de Fletcher sur 16 bits (`s1 += octet ; s2 += s1`, 8 bits chacun), un par ligne de `$BB80` |
| `'L'` (41 octets) | numéro de ligne, puis ses 40 octets tels quels (attributs et bit 7 compris) |

- **Le curseur ne compte pas** : quand il est inversé à l'écran (`cur_vis`), sa case est
  lue rétablie (bit 7 inversé de nouveau) pour les totaux comme pour les lignes. Sans cela
  le clignotement changerait un total toutes les 0,4 s. Le Mac dessine son propre curseur
  d'après la trame `S`.
- En HIRES plein écran, les totaux valent 0 et le Mac affiche « écran graphique ».

### Budget sous l'IRQ (à régler après mesure, § 10)

| Tâche | Par trame de 1/50 s |
|---|---|
| lecture | jusqu'à 4 octets reçus (le LOCI en garde 32) |
| totaux | 4 lignes (~2 ms) : la trame `S` part en 7 trames d'IRQ, ~0,15 s |
| émission | jusqu'à 8 octets, chacun après une attente de l'émetteur libre de ~1,2 ms au plus ; émetteur occupé : la suite à l'IRQ suivante |

Débit attendu à 9600 bauds : écran entier (28 lignes) en ~1,5 s ; une ligne changée en
moins de 0,1 s après la trame `S`. Au repos, le Mac demande `S` toutes les 0,5 s ; juste
après une touche, tout de suite.

### Liaison perdue

Le pilote ne parle que pour répondre : sans Mac, il se tait. Le Pico W retient parfois
l'envoi plusieurs dixièmes de seconde (`loci-modem-wifi.md`, « Contrôle de flux ») : le
service reprend simplement à l'IRQ suivante. Si l'émetteur reste occupé 5 s pendant une
réponse (modem débranché : le LOCI ne vide plus le registre), la réponse
est abandonnée et le voyant passe à `r` ; la console reste active (une nouvelle demande
relance le service). `REMOTE OFF` coupe et raccroche.

## 5. Côté Oric : ce qui est résident

| Partie | Octets estimés |
|---|---:|
| crochet dans l'IRQ, lecture (préfixes, place dans le tampon, touche rangée par `kb_push`, tiré de `kb_scan`) | 70 |
| service : totaux (curseur rétabli), ligne, trame et total, émission bornée | 160 |
| PUNCH, READER, fonctions 3 et 4 du BDOS | 30 |
| fonction 117 du BDOS (§ 6) | 40 |
| voyant `R` / `r` (`draw_flags`) et démarrage à chaud par `$FD 'B'` | 25 |
| **total** | **~325** |

Les estimations passées ont souvent doublé : prévoir jusqu'à **500** sur les 706 octets de
marge. Variables (~14 octets) dans `$FD13-$FD57` : état (port posé, console active, liaison
perdue), préfixe reçu, demande en cours, ligne et position, `s1`, `s2`, total de la trame,
compteur d'attente de l'émetteur, octet bas du port. Pointeur de ligne : `ZP_IRQP` (déjà
pris par `cur_toggle` sous l'IRQ ; les deux ne se recouvrent pas). Les adresses de lignes
viennent de `line_lo` / `line_hi` (page `$FF00`).

Pas dans une banque de la fenêtre : le service tourne à chaque IRQ, et la fenêtre sert à
PUT et IMG. Option de construction `SERIE` (lot 3 des banques, `etat.md` § 3), présente par
défaut.

- **PUNCH** (`$C012`, BDOS 4) : envoie A au port, attente de l'émetteur bornée à 5 s ;
  C = 1 si l'octet n'est pas parti, ou si aucun port n'est posé.
- **READER** (`$C015`, BDOS 3) : attend un octet du port ; rend `$1A` (^Z) tout de suite
  si aucun port n'est posé ou si la console à distance est active (le flux est à elle),
  et dès qu'une touche est tapée sur l'Oric (la touche reste dans le tampon).
- Le pilote survit au démarrage à chaud (variables en RAM overlay, réglage de l'ACIA
  intact) ; le démarrage à froid l'éteint. `AUTO.BAT` peut contenir `REMOTE hôte:port` :
  l'Oric se met de lui-même à disposition du Mac.

## 6. Contrat : ce qui s'ajoute

Accordé par Pierre (ajouts seulement, rien ne bouge) :

- PUNCH et READER, réservées au port série, reçoivent leur définition (§ 5) ; les
  fonctions 3 et 4 du BDOS les appellent.
- **Fonction 117 du BDOS, « série »**, bloc `[op, p1..p5]` comme 115 et 116 :

| op | Effet |
|---|---|
| 0 | état -> A : bit 0 port posé, bit 1 console active, bit 2 liaison perdue ; X = octet bas du port (0 : aucun) |
| 1 | pose le port : p1 = octet bas (`$80` LOCI, `$1C` Oricutron ; 0 : aucun, console coupée) |
| 2 | console à distance active |
| 3 | console à distance coupée |

  La version ROM rend `$FF` (règle du contrat). `progs/cpa.inc` : `F_SERIAL = 117` et
  les numéros d'op.
- Constantes du protocole (`$FD`, `$FE`, `$FF`, types) dans `progs/cpa.inc`, pour TERM,
  XFER et tout programme qui voudrait parler au démon.

## 7. REMOTE.COM

Trouve et règle l'ACIA (`ac_find`, `ac_setup`), compose par `ac_dial` (§ 8 : nom pris
dans `HOSTS`, port 2324 par défaut), pose le port et lève le drapeau par la fonction 117.

    REMOTE hote        compose et active (hote : nom de HOSTS,
                       adresse IP ou nom DNS ; :port facultatif)
    REMOTE /N          active sans composer (liaison ouverte par TERM)
    REMOTE OFF         coupe, puis +++ et ATH
    REMOTE             etat

Maquettes (37 colonnes au plus, sans accents ; anglais sur `cpa-en.dsk`) :

    A>REMOTE MAC
    Modem du LOCI ($0380)
    Appel de mac (192.168.1.20:2324)...
    Console a distance active (voyant R)
    A>

    A>REMOTE
    Console a distance : active
    Port : LOCI ($0380)
    A>

    A>REMOTE MAC
    Appel de mac (192.168.1.20:2324)...
    Pas de reponse (NO CARRIER)
    A>

- TERM et XFER refusent de partir quand la console est active (ils liraient l'ACIA à sa
  place) : `Console a distance active : REMOTE OFF`.
- Taille estimée : ~1,5 Ko (un bloc), la composition et `HOSTS` compris.

## 8. `HOSTS` et appel du modem (TERM, XFER, REMOTE)

Fait (lot 1). Mode d'emploi : `docs/manuel.md`, « Les hôtes : HOSTS », « Terminal série »
et « Transfert de fichiers » (`TERM mac`, `XFER R fic @mac`). Mise en œuvre :
`progs/acia_inc.s`, `ac_host` (recherche dans `HOSTS`) et `ac_dial` (appel), messages
dans `acia.msg` ; REMOTE s'en servira avec le port 2324. Choix faits en codant :

- XFER prend l'hôte en dernier, précédé de `@` : le CCP range le deuxième mot dans FCB2,
  qui est le fichier.
- `HOSTS` est cherché sur le lecteur courant, puis sur A: seulement (un lecteur vide d'un
  vrai Microdisc coûte plusieurs secondes) ; chaque disquette amorçable en porte un.
- Raccrocher : `ATH0` (le modem d'Oricutron refuse `ATH`) ; `ac_hang` viendra avec
  `REMOTE OFF`.
- Dans Oricutron, le numéro part sans signe de mode (`ATDT127.0.0.1:port`).
- TERM passe à 1 893 octets (un bloc), XFER à 3 065 (deux blocs).

## 9. Côté Mac : `tools/remote.py`

Python 3 de la bibliothèque standard seulement (rien à installer sur le Mac).

- **Démon** : `tools/remote.py serve [--port 2324] [--http 8040] [--lent]` attend
  l'Oric, tient la copie de l'écran, sert la page et l'interface locale. `--lent` : un
  octet toutes les 25 ms vers l'Oric, pour Oricutron (son 6551 perd un octet si l'Oric
  tarde) ; inutile avec le LOCI.
- **Ligne de commande** (parle au démon) : `remote.py touches $'DIR\n'` (même notation
  que `run_test.sh` : `\n`, `~` DEL, `\x01-\x04` flèches, `\x05` FUNCT, `\x1c` CTRL,
  `\x0f` SHIFT, `|` pause, `\x06` démarrage à chaud par `$FD 'B'`), `remote.py ecran`
  (texte comme `tools/screen.py`), `remote.py attendre 'A>' [secondes]` (attend qu'un texte
  paraisse sur l'écran). Avec eux, un script d'essai sur le vrai Oric s'écrit comme ceux
  d'Oricutron.
- **Page web** (`http://localhost:8040`, ou l'adresse du Mac depuis le téléphone) :
  écran 40 x 28 dessiné avec la police de CP/A (lue dans `src/font.s` par le démon) et
  les attributs (encre, papier, police secondaire, clignotement) ; touches du navigateur
  traduites ; bouton « Coller » : un texte du presse-papiers du Mac (copié dans
  n'importe quelle application) part vers l'Oric comme une suite de touches, accents
  retirés comme XFER `/T`, fins de ligne en CR. Le programme de l'Oric le reçoit comme une
  frappe très rapide : dans EDIT, on ouvre un fichier, on colle, on enregistre (un texte
  du Mac passe ainsi sur l'Oric sans XFER). Le contrôle de flux (§ 4) fait qu'aucune
  touche ne se perd, quel que soit le rythme d'EDIT.

        +------------------------------------------+
        | CP/A a distance   192.168.1.30   R  0,4 s |
        +------------------------------------------+
        |                                          |
        |        ecran 40 x 28 (police Oric)       |
        |                                          |
        +------------------------------------------+
        | [FUNCT] [CTRL-C] [ESC] [RESET]  [Coller] |
        +------------------------------------------+

  Touches : flèches `$08-$0B`, avec SHIFT `$F0-$F3`, avec CTRL `$F4-$F7` ; Ctrl + lettre
  1-26 (H à K : 28-31) ; Tab 29 ; Retour arrière et Suppr `$7F` ; Entrée 13 ; Échap 27 ;
  FUNCT : F1 (et le bouton, pour le téléphone).

### 9.1 Interface locale du démon

HTTP sur le port `--http` (8040), sans authentification (réseau de la maison) ; la page
web, la fenêtre tkinter et la ligne de commande s'en servent toutes.

| Requête | Réponse, effet |
|---|---|
| `GET /ecran?depuis=V&attendre=S` | JSON de l'écran (ci-dessous) ; seules les lignes changées depuis la version `V` (toutes si `V` = 0) ; avec `attendre`, la réponse attend jusqu'à `S` secondes (5 au plus) qu'une version plus récente paraisse (attente longue : pas de scrutation) |
| `POST /touches` | corps : octets bruts, codes du contrat (FUNCT `$80`), envoyés `$FE k` dans l'ordre ; 204 |
| `POST /coller` | corps : texte UTF-8 ; accents retirés comme XFER `/T`, fins de ligne en CR, tabulation 29, puis comme `/touches` ; 204 |
| `POST /reset` | `$FD 'B'` (démarrage à chaud) ; 204 |
| `GET /` | la page web |

    {"version": 812, "liaison": "active", "hote": "192.168.1.30",
     "mode": 0, "curseur": [4, 19, true], "delai": 0.4,
     "lignes": {"19": "1007413e444952...", ...}}

- `version` croît à chaque changement (ligne, curseur, mode, liaison). Une version plus
  petite que celle du client veut dire que le démon a redémarré : le client redemande
  tout (`depuis=0`).
- `liaison` : `attente` (l'Oric n'a pas encore appelé), `active`, `perdue` (plus de
  réponse de l'Oric) ; `delai` : âge en secondes du dernier cycle complet.
- `mode`, `curseur` (colonne, ligne, actif) : ceux de la trame `S` ; `lignes` : les
  40 octets de chaque ligne en hexadécimal, tels que la trame `L`.

### 9.2 Fenêtre tkinter : `tools/remote_tk.py` (Raspberry Pi Zero, Mac, Pi 400)

Même rôle que la page web, sans navigateur : pour un Pi Zero et son petit écran, posé à
côté de l'Oric ou ailleurs dans la maison. Python 3 et tkinter seulement.

    python3 tools/remote_tk.py [--demon URL] [--plein-ecran] [--etirer]
                               [--echelle E] [--sans-boutons] [--mem VIDAGE.mem]

- `--demon` : le démon à joindre (défaut `http://localhost:8040`). Le démon peut tourner
  sur le Pi Zero lui-même (l'Oric l'appelle : `pizero 192.168.1.40` dans `HOSTS`, puis
  `REMOTE pizero`), ou sur le Mac (`--demon http://192.168.1.20:8040`).
- Taille : la plus grande qui tient, entière à partir de 2, sinon une case de taille
  fixe (par exemple 8 x 10 points au lieu de 6 x 8 sur un écran de 480 x 320) : toutes
  les cases grandissent de la même façon, en doublant d'abord la colonne d'espacement et
  la rangée vide du bas, pour que les lettres restent nettes. `--etirer` remplit la
  place sans garder les proportions ; `--echelle` impose l'échelle.
- Rendu : celui de l'ULA (`tools/oric_ecran.py`) : police de CP/A lue dans `src/font.s`,
  encre, papier, inverse, double hauteur, clignotement ; le jeu secondaire est dessiné
  avec la police normale (CP/A ne l'initialise pas) ; les caractères redéfinis par un
  programme (sprites et tuiles de GRAPHER) ne sont pas vus. Curseur clignotant dessiné
  d'après la trame `S`. En SPLIT, les lignes 0 à 15 sont hachurées ; en HIRES plein
  écran, « Ecran graphique ». Seules les lignes changées sont redessinées.
- Touches : celles de la page web ; F1 FUNCT, F5 démarrage à chaud, F9 coller le
  presse-papiers, F11 plein écran, F10 quitte. Barre de boutons (FUNCT, CTRL-C, ESC,
  RESET, Coller) pour un écran tactile, ôtée par `--sans-boutons`.
- Ligne d'état : hôte, voyant (`R` active, `r` perdue, `-` attente), âge du dernier
  cycle. Démon injoignable ou Oric pas encore appelé : un message sur l'écran ; le
  client réessaie seul toutes les 2 s.
- `--mem` : montre un vidage de `tools/run_test.sh`, sans démon.

Sur le Pi Zero (Raspberry Pi OS avec bureau) : `sudo apt install python3-tk` si
`python3 -c "import tkinter"` échoue ; le dépôt (ou seulement `tools/remote_tk.py`,
`tools/oric_ecran.py` et `src/font.s`, à leur place) ; puis
`python3 tools/remote_tk.py --plein-ecran --sans-boutons --demon http://...`. Sur un
écran de 480 x 320, l'écran de l'Oric fait 320 x 280 points (480 x 280 avec `--etirer`).

### 9.3 Essais sans Oric : `tools/faux_demon.py`

Sert l'interface du § 9.1 comme le fera le démon, avec une mire (couleurs, inverse,
double hauteur, clignotement, police entière, invite `A>` qui affiche la frappe) ou des
vidages d'Oricutron passés à tour de rôle ; il affiche les touches reçues.

    python3 tools/faux_demon.py [--http 8040] [--periode S] [VIDAGE.mem ...]
    python3 tools/remote_tk.py --demon http://localhost:8040

`python3 tools/oric_ecran.py VIDAGE.mem SORTIE.png` dessine un vidage avec le même
rendu, pour le comparer à la capture d'Oricutron (`SORTIE.png` de `run_test.sh`).

### 9.4 Le Pi Zero en écran de l'Oric : `tools/pizero_ecran.sh`

Lance le serveur X sur la console texte où il est tapé (tty1), sans bureau ni
gestionnaire de fenêtres, avec la fenêtre du § 9.2 en plein écran, sans pointeur de la
souris ni mise en veille de l'écran. F10 dans la fenêtre : retour à la console ; si la
fenêtre s'arrête sur une erreur, elle est relancée.

    DEMON=http://192.168.1.20:8040 tools/pizero_ecran.sh   # démon sur le Mac
    FAUX=1 tools/pizero_ecran.sh                           # mire, sans Oric

- Variables : `DEMON` (défaut `http://localhost:8040`), `FAUX=1` (lance aussi
  `faux_demon.py` sur le Pi Zero, arguments dans `FAUX_ARGS`), `OPTIONS` (options de
  `remote_tk.py`, défaut `--sans-boutons`) ; d'autres options peuvent suivre la commande.
- À lancer depuis la console elle-même, pas par ssh (le serveur X prend le terminal
  courant).
- Paquets, sur Raspberry Pi OS Lite : `sudo apt install --no-install-recommends
  xserver-xorg xinit x11-xserver-utils python3-tk fonts-dejavu-core`.
- Au démarrage : connexion automatique sur la console (`raspi-config`, System Options,
  Boot / Auto Login, Console Autologin), puis à la fin de `~/.bash_profile` :

        if [ "$(tty)" = /dev/tty1 ] && [ -z "$DISPLAY" ]; then
          ~/cpa-oric/tools/pizero_ecran.sh
        fi

  Une connexion par ssh n'est pas touchée (elle n'est pas sur tty1).

## 10. Lots

1. **`HOSTS` et appel du modem** (§ 8) : fait ; à essayer sur le vrai Oric
   (`essais-materiel.md`).
2. **Mesures, sans code** (Pierre, sur le vrai Oric, avant le lot 3) : temps de `XFER`
   sur un fichier de 40 Ko (débit réel LOCI, Pico W, Mac).
3. **Pilote, REMOTE et démon** : tout ce qui fait la console à distance, dans les deux
   sens. Résident (§ 5), fonction 117, PUNCH / READER, REMOTE.COM, refus de TERM et XFER
   pendant la console, `remote.py` (démon, écho rapide, ligne de commande),
   `tools/test_remote.sh` dans Oricutron : l'écran tenu par le démon doit être celui du
   vidage mémoire (`screen.py`), après DIR, EDIT (texte de 2 Ko collé, puis relu par
   TYPE), CMDER, un menu FUNCT, GRAPHER en SPLIT ; démon tué au milieu d'une réponse ;
   `$FD 'B'`.
4. **Page web** : la fenêtre (rendu fidèle, police et attributs), le clavier, Coller,
   le téléphone. Elle ne fait qu'afficher et envoyer ce que le démon du lot 3 sait déjà
   faire. La fenêtre tkinter (§ 9.2) est faite : elle marche avec le démon du lot 3
   sans changement, s'il suit le § 9.1.

À vérifier sur le vrai Oric (à reporter dans `essais-materiel.md` au fil des lots) :
`HOSTS` et l'appel par XFER et TERM (lot 1) ; l'émetteur du LOCI libre tout de suite ou au
rythme de 9600 bauds (budget d'émission), le délai réel de l'écho, un texte collé de
plusieurs Ko dans EDIT sans perte, le bouton RESET et un démarrage à chaud avec la console
active, Pico débranché pendant une réponse (voyant `r`, Oric qui continue) (lot 3). Sur le
Pi Zero : la fenêtre tkinter en plein écran (§ 9.2), sa vitesse (un écran entier se
redessine en ~0,04 s sur un PC, sans doute vers 1 s sur un Pi Zero), son clavier.

## 11. Questions ouvertes

Aucune. Écarté : une copie de tout ce qui passe par CONOUT vers le Mac (un journal) ;
l'écran suffit, et `PUT` capture déjà la sortie d'une commande dans un fichier.
