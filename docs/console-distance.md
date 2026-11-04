# Pilote série et console à distance

But : un Mac (ou le Pi) **tape et lit à la place du clavier et de l'écran** d'un vrai Oric,
par le modem WiFi du LOCI (`docs/loci-modem-wifi.md`). Usages : piloter les essais sur le
vrai Oric comme `tools/run_test.sh` le fait dans Oricutron, coller un texte dans EDIT,
travailler sur l'Oric depuis la fenêtre du Mac ou le navigateur d'un téléphone. La
console à distance doit survivre aux programmes : elle est dans le BIOS.

Fait : le pilote résident (`src/serial.s`, option `SERIE`), la fonction 117, PUNCH et
READER, `REMOTE.COM`, le démon `tools/remote.py` et sa ligne de commande, la page web
(§ 9), la fenêtre tkinter (§ 9.2), le faux démon (§ 9.3), la vitrine (§ 9.5) et la
publication sur Internet par une passerelle, en lecture seule (§ 9.6) ; essayés dans
Oricutron (`tools/test_remote.sh`), la page avec le faux démon. Mode d'emploi : `docs/manuel.md`, « Console à distance :
REMOTE ».

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
- **Les caractères redéfinis aussi** (sprites et tuiles de GRAPHER, grille d'EDSPRITE) : en
  mode texte, le Mac suit la police elle-même (`$B400-$BB7F`), découpée en 48 lignes de
  40 octets (cinq caractères) numérotées 28 à 75 à la suite de celles de l'écran, avec les
  mêmes totaux et les mêmes trames (§ 4, « Police »).
- **Le service tourne sous l'IRQ de 50 Hz** : il marche pendant un calcul, pendant ASM ou
  LOGO, avec un programme qui ne lit pas le clavier par le BDOS. Il s'arrête quand les
  interruptions sont coupées (accès disque) : le LOCI, le Pico et TCP gardent ce qui arrive
  (`loci-modem-wifi.md`, « Contrôle de flux ») ; rien n'est perdu.
- **Le clavier de l'Oric reste actif** : les deux sources remplissent le même tampon.

## 2. Ligne et réglages

- Port : celui de `acia_inc.s` (LOCI `$0380`, Oricutron `$031C`), 9600 bauds 8N1, DTR,
  sans interruption de l'ACIA, réglé par REMOTE ; accès par `LDA` / `STA` absolus
  seulement. Les trois routines de registre du pilote (`sr_rsta`, `sr_rdat`, `sr_wdat` :
  `LDA $0381` / `LDA $0380` / `STA $0380`, suivies de `RTS`) sont dans la RAM overlay ;
  leur octet bas est posé par la fonction 117 (§ 6).
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
| `$FD 'L' n` | demande de la ligne `n` (0-27) (réponse `L`) ; `n + $80` : les lignes `n` à 27, une trame `L` chacune, à la suite, sans autre demande (le Mac s'en sert à partir de 3 lignes changées) |
| `$FD 'C' n` | totaux des lignes de police `n` à `n+7` (28 ≤ `n` ≤ 68) (réponse `C`) |
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
| `'S'` (60 octets) | mode (0 texte, 1 SPLIT, 2 HIRES plein écran ; bit 7 = `SCR_PROG`, écran texte au programme), colonne et ligne du curseur, curseur actif, puis 28 totaux de Fletcher (`s1 += octet ; s2 += s1`, 8 bits chacun, `s1` envoyé d'abord), un par ligne de `$BB80` |
| `'L'` (41 octets) | numéro de ligne, puis ses 40 octets tels quels (attributs et bit 7 compris) |
| `'C'` (16 octets) | les totaux de Fletcher (`s1`, `s2`) des 8 lignes de police demandées |

- **Le curseur ne compte pas** : quand il est inversé à l'écran (`cur_vis`), sa case est
  lue rétablie (bit 7 inversé de nouveau) pour les totaux comme pour les lignes. Sans cela
  le clignotement changerait un total toutes les 0,4 s. Le Mac dessine son propre curseur
  d'après la trame `S`.
- En HIRES plein écran (mode 2), le Mac ne demande pas de lignes et affiche « Ecran
  graphique » ; en SPLIT (mode 1), il ne compare que les lignes 16 à 27.
- Le mode 2 est reconnu comme `hires_on` du BIOS : mode texte pour le système, attribut
  `$1E` dans la dernière case de l'écran.

### Police (caractères redéfinis)

Ligne `n` de 28 à 75 : les 40 octets en `$B400 + 40 × (n − 28)` ; `L n` et la suite
`L n+$80` (jusqu'à 75) marchent comme pour l'écran. Un caractère prend 8 octets : une
ligne en contient cinq exactement, un caractère n'est jamais coupé. Utiles : 6 à 25
(caractères 32-127 du jeu standard) et 32 à 47 (32-111 du jeu secondaire ; 112-127 sont
dans les lignes 0-3 de l'écran, comme pour l'ULA) ; les autres portent les codes 0-31
(attributs), jamais dessinés.

- **Seulement en mode texte** : en HIRES et en SPLIT, `$B400` est dans l'image (la police
  du SPLIT est en `$9800`) ; le Mac n'en demande rien, et dessine les lignes de texte du
  SPLIT avec la police de CP/A.
- **Le Mac** : à la première trame `S` en mode texte de chaque appel, il lit les 48
  lignes (`L 28+$80`, 1,8 s dans Oricutron) ; un pilote qui ne répond pas ne connaît pas
  la police (ancien pilote) : elle n'est plus demandée pendant cet appel. Ensuite, à
  chaque cycle (au repos toutes les 0,5 s), des trames `C` sur les cinq tranches utiles
  (28+6, 28+14, 28+22, 28+32, 28+40) : chaque tranche qui a changé depuis moins de 10 s
  (sprite animé) à chaque cycle, plus deux autres à tour de rôle (toute la police en
  1,5 s au repos, plus vite quand l'écran change : les cycles s'enchaînent) ; toutes au retour en mode texte. Lignes changées : `L`, ou une suite.
- **Coût côté Oric** : une trame `C` calcule 8 totaux (320 octets lus) ; aucune variable
  en plus. Pilote : +65 octets.

### Budget sous l'IRQ

Plafonds posés avec le port (fonction 117, op 1 ; table `sr_par` de `src/serial.s`, variables
`sr_rxn`, `sr_rxw`, `sr_txn`, `sr_bdg` en `$FD23-$FD26`) : un vrai 6551 (Oricutron, carte
série) n'a qu'un octet reçu et émet au rythme de la ligne ; le LOCI garde 32 octets reçus, tout
de suite lisibles, et prend un octet émis dès que l'USB l'accepte (son ACIA émulée n'a pas de
cadence : les 9600 bauds ne sont qu'un réglage transmis au modem).

| Tâche | Par trame de 1/50 s : 6551 | LOCI (`$80`) |
|---|---|---|
| lecture | 4 octets au plus ; le premier sans attendre, les suivants après ~1,2 ms au plus | 16 octets au plus (8 touches) ; attente des suivants ~0,2 ms |
| totaux | calculés pendant l'émission, quand leur tour vient (~0,6 ms par ligne) : pas de tampon | idem |
| émission | 24 octets au plus, tant que l'attente de l'émetteur libre, comptée sur toute l'IRQ, ne dépasse pas ~6 ms ; émetteur occupé : la suite à l'IRQ suivante | 64 octets au plus (une trame `S` entière), attente ~7,5 ms au plus |

Mesuré sur le vrai Oric (LOCI, Pico au firmware de `tools/pico-modem/`, démon sur le Mac) :
27 lignes en 0,4 s, soit ~3 Ko/s, le plafond de 64 octets par IRQ (1,0 s avec ceux du 6551) ;
écho 0,21 s ; `VER` sur un écran plein 0,8 à 0,9 s.

Les plafonds se changent sans reconstruire (essais) : `DEBUG`, puis `M FD23 rx at tx bu` ;
ils reviennent à la table au prochain `REMOTE`.

Mesuré dans Oricutron (9600 bauds, émetteur libre au bout de ~1 ms) : 8 octets par IRQ,
soit la trame `S` (64 octets) en 8 IRQ (0,16 s), une trame `L` (45 octets) en 6 ; pendant
une réponse, le service prend ~10 ms sur 20, le programme continue plus lentement. Un texte
collé de 2 Ko arrive dans EDIT en ~40 s (~55 touches par seconde). Au repos, le Mac demande
`S` toutes les 0,5 s ; juste après une touche, tout de suite. Sur le LOCI : à mesurer
(`essais-materiel.md`).

### Liaison perdue

Le pilote ne parle que pour répondre : sans Mac, il se tait. Le Pico W retient parfois
l'envoi plusieurs dixièmes de seconde (`loci-modem-wifi.md`, « Contrôle de flux ») : le
service reprend simplement à l'IRQ suivante. Si l'émetteur reste occupé 5 s pendant une
réponse (modem débranché : le LOCI ne vide plus le registre), la réponse
est abandonnée et le voyant passe à `r` ; la console reste active (une nouvelle demande
relance le service). `REMOTE OFF` coupe et raccroche.

## 5. Côté Oric : ce qui est résident

`src/serial.s`, inclus avec l'option de construction `SERIE` (présente par défaut,
`build.sh`) :

| Partie | Octets |
|---|---:|
| `sr_irq` : appelé par l'IRQ après `snd_tick` ; lecture (préfixes, place dans le tampon du clavier, touche rangée par `kb_push` de `kb_scan`), émission bornée, liaison perdue | 132 |
| `sr_rx` : préfixes et demandes ; `$FD 'B'` | 77 |
| `sr_next` : octet suivant de la trame (en-tête, données, total) | 148 |
| `sr_fl`, `sr_line`, `sr_byte`, `sr_lda` : totaux et lecture d'une ligne, case du curseur rétablie | 80 |
| registres (`sr_rsta`, `sr_rdat`, `sr_wdat`) | 12 |
| fonction 117 (`sr_call`) | 76 |
| PUNCH, READER (fonctions 4 et 3) | 72 |
| voyant (`draw_flags`, table `sr_flg`), aiguillage du BDOS, appel dans l'IRQ (moins les anciennes entrées vides de PUNCH et READER) | 25 |
| ajouts : suite de lignes (`L n+$80`), attente de l'émetteur comptée sur l'IRQ (`sr_bud`) | 38 |
| **total** | **660** |

Variables `sr_port`... (`src/hw.inc`, `$FD13-$FD21`) : octet bas du port, état (console
active, liaison perdue), préfixe reçu, trame en cours, position, ligne demandée, ligne
lue, `s1`, `s2`, total, IRQ sans émission, longueur, compteur, départ du délai de PUNCH.
Effacées au démarrage à froid seulement. La ligne est lue par une instruction `LDA
abs,Y` dont l'adresse est posée (`sr_lda`, RAM overlay) : pas de pointeur en page zéro.
Les adresses de lignes viennent de `line_lo` / `line_hi` (page `$FF00`).

Pas dans une banque de la fenêtre : le service tourne à chaque IRQ, et la fenêtre sert à
PUT et IMG.

- **PUNCH** (`$C012`, BDOS 4) : envoie A au port, attente de l'émetteur bornée à 5 s
  (compteur 50 Hz : interruptions permises) ; rend A = 0 et C = 0 si l'octet est parti,
  A = `$FF` et C = 1 sinon, ou si aucun port n'est posé.
- **READER** (`$C015`, BDOS 3) : attend un octet du port ; rend `$1A` (^Z) tout de suite
  si aucun port n'est posé ou si la console à distance est active (le flux est à elle),
  et dès qu'une touche est tapée sur l'Oric (la touche reste dans le tampon).
- Le pilote survit au démarrage à chaud (variables en RAM overlay, réglage de l'ACIA
  intact) ; le démarrage à froid l'éteint. `AUTO.BAT` peut contenir `REMOTE hôte:port` :
  l'Oric se met de lui-même à disposition du Mac.
- `$FD 'B'` fait `JMP wboot` depuis l'IRQ (pile remise, matériel et console remis en ordre,
  retour au CCP), sans le message `*RESET* at`.

## 6. Contrat : ce qui s'ajoute

Ajouts seulement, rien ne bouge (`architecture.md` § 2) :

- PUNCH et READER, réservées au port série, reçoivent leur définition (§ 5) ; les
  fonctions 3 et 4 du BDOS les appellent.
- **Fonction 117 du BDOS, « série »**, bloc `[op, p1..p5]` comme 115 et 116 :

| op | Effet |
|---|---|
| 0 | état -> A : bit 0 port posé, bit 1 console active, bit 2 liaison perdue ; X = octet bas du port (0 : aucun) |
| 1 | pose le port : p1 = octet bas (`$80` LOCI, `$1C` Oricutron ; 0 : aucun, console coupée) |
| 2 | console à distance active |
| 3 | console à distance coupée |

  Op 1 à 3 effacent aussi le préfixe et la trame en cours. La version ROM, et une
  construction sans `SERIE`, rendent `$FF` (règle du contrat). `progs/cpa.inc` :
  `F_SERIAL = 117`, `SE_STATE`, `SE_PORT`, `SE_ON`, `SE_OFF`.
- Constantes du protocole dans `progs/cpa.inc` : `RP_REQ` (`$FD`), `RP_KEY` (`$FE`),
  `RP_FRM` (`$FF`), `RP_PORT` (2324).

## 7. REMOTE.COM

`progs/remote.s` (1 966 octets, un bloc ; 1 918 en anglais). Coupe la console si elle est
active, trouve et règle l'ACIA (`ac_find`, `ac_setup`), compose par `ac_dial` (§ 8 : nom
pris dans `HOSTS`, port 2324 par défaut), pose le port et lève le drapeau par la fonction
117. `REMOTE /N` ne règle l'ACIA que si elle ne l'est pas (comme XFER). `REMOTE OFF` :
fonction 117 op 3, puis `ac_hang` (`AT`, sinon `+++` ; puis `ATH0`).

    REMOTE hote        compose et active (hote : nom de HOSTS,
                       adresse IP ou nom DNS ; :port facultatif)
    REMOTE /N          active sans composer (liaison ouverte par TERM)
    REMOTE OFF         coupe, puis +++ et ATH
    REMOTE             etat

Écrans (37 colonnes au plus, sans accents ; anglais sur `cpa-en.dsk`) :

    A>REMOTE MAC
    Modem du LOCI (ACIA 0380)
    Appel de 192.168.1.20:2324...
    CONNECT
    Console a distance active (voyant R)
    A>REMOTE
    Console a distance : active
    Port : LOCI (ACIA 0380)
    A>REMOTE OFF
    Console a distance coupee

- Un appel raté donne la réponse du modem (`NO CARRIER`, `BUSY`...) ou `Pas de reponse
  du modem` ; la console reste coupée. Sans pilote série (construction sans `SERIE`) :
  `Pas de pilote serie dans le systeme`.
- TERM et XFER refusent de partir quand la console est active (ils liraient l'ACIA à sa
  place) : `Console a distance : REMOTE OFF` (`ac_busy` d'`acia_inc.s`).
- REMOTE est sur toutes les disquettes amorçables (caché sur les disquettes par usage,
  comme TERM et XFER).

## 8. `HOSTS` et appel du modem (TERM, XFER, REMOTE)

Mode d'emploi : `docs/manuel.md`, « Les hôtes : HOSTS », « Terminal série » et
« Transfert de fichiers » (`TERM mac`, `XFER R fic @mac`). Mise en œuvre :
`progs/acia_inc.s`, `ac_host` (recherche dans `HOSTS`), `ac_dial` (appel), `ac_hang`
(raccrocher), `ac_busy` (refus pendant la console), messages dans `acia.msg` ; REMOTE s'en
sert avec le port 2324. Choix faits en codant :

- XFER prend l'hôte en dernier, précédé de `@` : le CCP range le deuxième mot dans FCB2,
  qui est le fichier.
- `HOSTS` est cherché sur le lecteur courant, puis sur A: seulement (un lecteur vide d'un
  vrai Microdisc coûte plusieurs secondes) ; chaque disquette amorçable en porte un.
- Raccrocher : `ATH0` (le modem d'Oricutron refuse `ATH`).
- Dans Oricutron, le numéro part sans signe de mode (`ATDT127.0.0.1:port`).
- Avant `AT`, `ac_at` envoie un CR seul, puis jette ce qui arrive jusqu'à 0,2 s de
  silence (`ac_purge`). Le CR vide la ligne de commande du modem : des octets partis
  pendant une liaison coupée (XMODEM, frappe dans TERM) s'y accumulent, et `AT` y aurait
  donné `ERROR` ; en mode commande, une ligne vide ne donne aucune réponse sur le Pico W
  (une ligne vide sur Oricutron), et sur une liaison ouverte, un CR seul est ignoré par
  `xfer_server.py` et par le démon. Ce qu'on jette, ce sont les réponses en retard (un
  `NO CARRIER` laissé par un serveur arrêté, l'`OK` de `ATH0`...), qui décalaient les
  réponses d'une commande. Après `ATDT`, un `OK` est encore sauté.
- `xfer_server.py` et `remote.py` acceptent un nouvel appel à tout moment : il remplace la
  connexion en cours. Un Oric (ou un LOCI) disparu sans raccrocher laissait sinon le
  serveur attendre sans fin sur une connexion morte ; le nouvel appel aboutissait
  (`CONNECT` : le système du Mac accepte la connexion) mais le serveur ne le servait pas.
  Sondes TCP (keepalive) en plus.
- TERM : 2 007 octets (un bloc), XFER : 3 179 (deux blocs).

## 9. Côté Mac : `tools/remote.py`

Python 3 de la bibliothèque standard seulement (rien à installer sur le Mac).

- **Journal du démon** : `logs/remote.log` du dépôt (`--log` pour un autre fichier ; 1 Mo,
  trois anciens gardés, `logs/` hors de git) : au démarrage, version du démon (`VERSION`),
  commit du dépôt (« remote.py modifié » s'il diffère), Python, machine, arguments et
  paramètres ; puis les appels, chaque cycle qui change l'écran (touches, durée de
  l'écho, de la trame `S`, des lignes, demande groupée ou ligne par ligne), les attentes
  dépassées, les trames refusées (début en hexadécimal), une liaison perdue, et un bilan
  par minute. Lisible sans console : `GET /journal?n=200`, `GET /version` ; la réponse
  de `/ecran` porte aussi les compteurs (`stats`).
- **Démon** : `tools/remote.py serve [--port 2324] [--http 8040] [--lent]
  [--spectateurs ADRESSES] [--max-spectateurs N]` attend l'Oric, tient la copie de l'écran, sert l'interface
  locale. Un nouvel appel de l'Oric remplace le précédent. `--spectateurs` (adresses ou
  réseaux, séparés par des virgules : `10.77.0.1`, `192.168.2.0/24`) : les clients venus
  de là regardent seulement (§ 9.6). `--lent` : un octet toutes les 25 ms vers l'Oric (essai ;
  inutile avec le LOCI comme avec Oricutron, dont le modem garde ce qui arrive).
- **Touches** : celles qui attendent partent d'un coup (1 024 au plus), chacune `$FE k` ;
  le pilote ne les lit que si le tampon du clavier a de la place, c'est donc le programme
  de l'Oric qui donne le rythme. La demande `S` qui suit attend 1 s, plus 0,1 s par touche
  envoyée au-delà de 4. L'écho rapide (ligne du curseur) ne suit qu'un envoi de 4
  touches au plus (une frappe, pas un texte collé). Liaison perdue : 5 s sans trame
  valide (plus le délai de la demande). Délai d'une réponse : 3 s (`DELAI`) avant de la
  redemander : le modem WiFi retient parfois l'envoi plus d'une seconde (vu sur le vrai
  Oric), et une demande répétée trop tôt fait recommencer la trame en cours sur l'Oric.
  La demande groupée n'est abandonnée qu'après 3 suites sans réponse. Sous Linux, le
  démon acquitte chaque réception tout de suite (`TCP_QUICKACK`) : le modem n'attend
  pas l'acquit retardé avant d'envoyer la suite.
- **Ligne de commande** (parle au démon) : `remote.py touches $'DIR\n'` (même notation
  que `run_test.sh` : `\n`, `~` DEL, `\x01-\x04` flèches, `\x05` FUNCT, `\x1c` CTRL,
  `\x0f` SHIFT, `|` pause, `\x06` démarrage à chaud par `$FD 'B'`), `remote.py ecran`
  (texte comme `tools/screen.py`), `remote.py attendre 'A>' [secondes]` (attend qu'un texte
  paraisse sur l'écran). Avec eux, un script d'essai sur le vrai Oric s'écrit comme ceux
  d'Oricutron.
- **Page web** (`tools/remote.html`, servie par le démon sur `GET /` :
  `http://localhost:8040` sur la machine du démon, `http://adresse:8040` depuis un
  téléphone ou un autre ordinateur ; `?demon=http://adresse:8040` : parler à un autre
  démon que celui qui sert la page). Ses requêtes ont des adresses relatives
  (`ecran`, `touches`...) : derrière une passerelle, la page marche sous un chemin
  (`https://site/cpa/`, avec la barre finale). Un seul fichier, sans bibliothèque, à garder à côté
  d'`oric_ecran.py` ; le démon y insère la police de CP/A (`page_web()`, lue dans
  `src/font.s`). Fichier ou police absents : réponse 500 qui le dit.

        +-------------------------------------------------+
        | CP/A a distance   10.0.0.2   R             0,4 s |
        +-------------------------------------------------+
        |                                                 |
        |        ecran 40 x 28 (police de CP/A)           |
        |                                                 |
        +-------------------------------------------------+
        | FUNCT ESC TAB CTRL SHIFT   < ^ v >  RETURN      |
        | ^C  Clavier  Coller  RESET                      |
        +-------------------------------------------------+

  - Rendu : celui d'`oric_ecran.py` (§ 9.2), refait en JavaScript, identique au point
    près (vérifié sur la mire du faux démon) ; curseur et clignotement à 0,32 s ; en
    SPLIT, lignes 0 à 15 hachurées ; en HIRES plein écran, « Ecran graphique ».
    Échelle entière quand elle tient (lettres nettes), sinon la plus grande possible.
  - Ligne d'état : hôte (l'Oric), voyant (`R` active, `r` perdue, `-` attente), âge du
    dernier cycle complet. Messages sur l'écran : attente de l'appel, liaison perdue,
    démon injoignable (nouvel essai toutes les 2 s).
  - Lecture : `GET /ecran` en attente longue (5 s), seules les lignes changées. Envois
    dans l'ordre, une frappe rapide regroupée en un seul `POST /touches`.
  - Clavier de l'ordinateur : flèches `$08-$0B`, avec SHIFT `$F0-$F3`, avec CTRL
    `$F4-$F7` ; Ctrl + lettre 1-26 (H à K : 28-31), Ctrl-Espace et Ctrl-@ 0, Ctrl-[ 27 ;
    Tab 29 ; Retour arrière et Suppr `$7F` ; Entrée 13 ; Échap 27 ; F1 FUNCT. Un
    caractère accentué part par `/coller` (accents retirés par le démon). Cmd (Mac) est
    laissé au navigateur : Cmd-V colle le presse-papiers vers l'Oric, Cmd-R recharge.
    Certaines combinaisons Ctrl sont gardées par le navigateur (Ctrl-W, Ctrl-T, Ctrl-N
    dans Chrome) : le bouton CTRL puis la lettre les remplace.
  - Téléphone : le bouton Clavier ouvre le clavier du téléphone (une zone de saisie
    invisible : rien n'y reste, chaque caractère part à l'Oric, Retour 13, effacement
    `$7F`) ; la page se tient dans la partie visible, écran en haut, boutons au-dessus du
    clavier. Les boutons ne prennent pas le focus : le clavier reste ouvert. CTRL et
    SHIFT valent pour la touche suivante (lettre ou flèche) ; RETURN à côté des flèches :
    un menu se parcourt et se valide sans le clavier du téléphone.
  - Coller : le presse-papiers est lu directement quand le navigateur le permet
    (`localhost`) ; sinon (téléphone en http), une zone où coller le texte, puis
    Envoyer. Le texte part par `/coller` (accents retirés comme XFER `/T`, fins de ligne
    en CR) : dans EDIT, on ouvre un fichier, on colle, on enregistre (un texte du Mac
    passe ainsi sur l'Oric sans XFER) ; le contrôle de flux (§ 4) fait qu'aucune touche
    ne se perd.
  - RESET : deux appuis à moins de 3 s (`Sur ?`), puis `POST /reset` (démarrage à
    chaud).
  - Spectateur (`"lecture_seule": true` dans la réponse de `/ecran`, ou un envoi
    refusé par 403) : ni boutons ni clavier, « en direct, lecture seule » dans la
    ligne d'état.

### 9.1 Interface locale du démon

HTTP sur le port `--http` (8040), sans authentification (réseau de la maison) ; la page
web, la fenêtre tkinter et la ligne de commande s'en servent toutes.

| Requête | Réponse, effet |
|---|---|
| `GET /ecran?depuis=V&attendre=S` | JSON de l'écran (ci-dessous) ; seules les lignes changées depuis la version `V` (toutes si `V` = 0) ; avec `attendre`, la réponse attend jusqu'à `S` secondes (5 au plus) qu'une version plus récente paraisse (attente longue : pas de scrutation) |
| `POST /touches` | corps : octets bruts, codes du contrat (FUNCT `$80`), envoyés `$FE k` dans l'ordre ; 204 |
| `POST /coller` | corps : texte UTF-8 ; accents retirés comme XFER `/T`, fins de ligne en CR, tabulation 29, puis comme `/touches` ; 204 |
| `POST /reset` | `$FD 'B'` (démarrage à chaud) ; 204 |
| `GET /` | la page web (`tools/remote.html`, police insérée) |
| `GET /version`, `GET /journal?n=N` | version et paramètres du démon ; les N dernières lignes du journal |

Un spectateur (`--spectateurs`) reçoit 403 pour les `POST`, `/version` et `/journal` ;
sa réponse de `/ecran` n'a ni `stats` ni `humain`, mais `"lecture_seule": true`. Il est
compté par son adresse réelle (la première de `X-Forwarded-For`, posée par Apache)
pendant 20 s après sa dernière demande ; au-delà de `--max-spectateurs` (40), un
nouveau venu reçoit 503 (la page réessaie 30 s plus tard). `spectateurs` (dans toutes
les réponses de `/ecran`) : le nombre en ligne, affiché sur la ligne d'état de la page.
Un appel du port de l'Oric (2324) venu d'une adresse de spectateur est refusé. Un
`POST` sans l'en-tête `X-Vitrine` (page, fenêtre, ligne de commande) note l'heure d'une
frappe humaine : la vitrine se met en pause (§ 9.5).

    {"version": 812, "liaison": "active", "hote": "192.168.1.30",
     "mode": 0, "curseur": [4, 19, true], "delai": 0.4,
     "lignes": {"19": "1007413e444952...", ...},
     "police": {"22": "0c1e3f3f1e0c0000...", ...}}

- `version` croît à chaque changement (ligne, curseur, mode, liaison). Une version plus
  petite que celle du client veut dire que le démon a redémarré : le client redemande
  tout (`depuis=0`).
- `liaison` : `attente` (l'Oric n'a pas encore appelé), `active`, `perdue` (plus de
  réponse de l'Oric) ; `delai` : âge en secondes du dernier cycle complet.
- `mode`, `curseur` (colonne, ligne, actif) : ceux de la trame `S` ; `lignes` : les
  40 octets de chaque ligne en hexadécimal, tels que la trame `L` ; `police` : de même,
  les lignes de police reçues (clé `k` de 0 à 47, ligne `28 + k` du pilote, octets en
  `$B400 + 40 × k`) changées depuis `V`, absente tant que rien n'est reçu.
- `humain` : secondes depuis la dernière frappe qui ne vient pas de la vitrine (`null` :
  aucune) ; `stats` : compteurs de la liaison (diagnostic).

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
- Rendu : celui de l'ULA (`tools/oric_ecran.py`) : encre, papier, inverse, double
  hauteur, clignotement ; en mode texte, les jeux standard et secondaire tels que l'Oric
  les a en mémoire (police envoyée par le démon, § 4 « Police » : sprites, tuiles,
  EDSPRITE ; `polices()`), la police de CP/A (`src/font.s`) pour ce qui n'est pas encore
  reçu et pour les lignes de texte du SPLIT. La page web fait de même (rendu comparé
  point par point). Curseur clignotant dessiné
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

Sert l'interface du § 9.1 (page web comprise) comme le démon, avec une mire (couleurs, inverse,
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

### 9.5 Vitrine : `tools/vitrine.py`

CP/A montré en boucle, sans personne, pour les spectateurs de la page (§ 9.6) : la
vitrine tape sur l'Oric par le démon, comme quelqu'un qui s'en servirait.

    python3 tools/vitrine.py [--demon URL] [--humain S] [--scenes a,b,...] [--une]
    python3 tools/vitrine.py --liste

- **Rythme** : une scène de spectacle (`heure`, `mosaique`, `edit`, `debug`, `cmder`,
  `edsprite` ; marquées `*` par `--liste`), puis deux commandes au prompt, et ainsi de
  suite ; dans chaque groupe, tirage au hasard pondéré, jamais deux fois la même de
  suite ; moins d'une seconde entre deux scènes (0,3 à 1 s). Un programme effacé par
  CMDER passe en tête de la scène de spectacle suivante.
- **Scènes** : `heure` (HORLOGE), `mosaique` (MOSAIQUE), `dir` (DIR,
  DIRS, STAT), `completion` (TAB sur la commande puis sur le nom, TYPE), `type`, `aide`
  (HELP et une rubrique), `menus` (FUNCT : barre, menus déroulés, parfois Version),
  `usb` (USBDIR, `USBDIR /S`, USBMOUNT), `debug` (`DEBUG MEM` : `L C000`, `D BB80`,
  l'écran vu par lui-même...), `edit` (un `.GRX` parcouru, une recherche, sortie sans
  rien changer), `cmder` (déplacements, tris, infos ; six fois sur dix, si les deux
  programmes sont là, efface l'un d'eux : filtre `/` sur son nom, DEL, `O` seulement si la
  question nomme ce fichier, puis sans filtre), `edsprite` (EDSPRITE sur `DUN.SPR`,
  sinon un autre `.SPR` de la disquette, sinon `edit` : curseur dans la grille, codes
  `^H`, copie du sprite (`^C` `^V` dans la liste) retournée par Dessin/Miroir horizontal,
  Vue/Décor, Vue/Animer, puis `^Q` et `O` à `Fichier modifie. Quitter (O/N) ?` : rien
  n'est enregistré, la scène se rejoue à l'identique ; ses caractères redéfinis
  sont vus par la page, § 4 « Police »), `echo` (l'heure au prompt),
  `divers` (VER, MEM, CLS). Frappe de 5 à 12 touches par seconde, avec des hésitations ;
  pauses de fin d'écran (`-- Suite`) passées après un temps de lecture.
- **Deux programmes GRAPHER** en mode texte (LORES), dans `tools/vitrine/` :
  `MOSAIQUE.GRX n` (n tableaux tirés au hasard : pluie de couleurs, cadres concentriques
  qui tournent, rayures qui défilent par `ROTH`, damier, bandes par `ROTV` ; chaque case
  est un attribut de papier, donc une tuile de couleur ; ~13 s par tableau) et
  `HORLOGE.GRX n` (l'heure en grands chiffres de couleur pendant n secondes, 15 à 25 ;
  la mosaïque : 2 ou 3 tableaux ; l'Oric
  n'a pas d'horloge : le programme demande l'heure, la vitrine la tape. Chiffres
  dessinés par rangées : une chaîne d'attributs par motif de 3 points, écrite par
  `PRINT` ; une seconde dure `DELAY 16` plus ~0,68 s de dessin, mesuré dans Oricutron :
  ~2 s de retard par minute). Au démarrage, la vitrine note ceux qui manquent
  (`DIR *.GRX`, et `DIR *.SPR` pour EDSPRITE) ; la première scène qui s'en sert les écrit
  dans EDIT, à la vue de tous : texte collé, `^S`, `^Q`, puis les lance. Rien d'autre
  n'est écrit, effacé ni modifié.
- **Langue** : la même vitrine pour `cpa.dsk` et `cpa-en.dsk` ; la langue du système est
  reconnue au démarrage par la barre des menus (`Systeme` ou `System`), `--langue fr|en`
  la force. Table `TEXTES` de `vitrine.py` : ce que la vitrine lit (`-- Suite` / `-- More`,
  questions `(O/N)` / `(Y/N)`...) et tape (réponse `O` / `Y`, rubriques de HELP, phrases
  d'ECHO). Essayé dans Oricutron sur les deux disquettes.
- **Reprise** : chaque scène part du prompt, ligne vide ; sinon ESC, `^Q`, `^C`,
  RETURN, et en dernier recours le démarrage à chaud (`/reset`). Liaison pas active :
  attente. Démon injoignable : nouvel essai toutes les 10 s.
- **Quelqu'un tape** (page, fenêtre, ligne de commande ; tout `POST` sans l'en-tête
  `X-Vitrine`) : la scène s'arrête et la vitrine attend `--humain` secondes (120) sans
  frappe avant de reprendre. Une frappe sur le clavier de l'Oric lui-même ne se voit pas :
  arrêter la vitrine (CTRL-C) pour s'en servir.
- La vitrine lit l'heure de la machine où elle tourne (Mac, simon) : celle de Paris.

### 9.6 Publier sur Internet : passerelle, lecture seule

Le démon n'a ni authentification ni chiffrement (réseau de la maison). Pour montrer
l'Oric à d'autres (un forum), une passerelle sur un serveur public (VPS) sert la page en
HTTPS et ne laisse passer que la lecture ; la box n'ouvre aucun port.

    navigateur --HTTPS--> Apache (VPS) --WireGuard--> démon (simon) :8040 --> Oric

    python3 tools/passerelle.py --vps NOM [--chemin /cpa/] [--reseau 10.77.0]
                                [--utilisateur pi] [--depot /home/pi/cpa-oric]

écrit dans `logs/passerelle/` (pas versionné : les clés ne quittent pas la machine) les
fichiers à copier et `LISEZMOI.txt`, les commandes dans l'ordre. Clés WireGuard calculées
par le script (X25519, RFC 7748, vérifiées contre `wg pubkey`), gardées dans
`cles.json` : relancer le script ne les change pas.

- **Tunnel** : WireGuard entre le VPS (`10.77.0.1`) et la machine du démon
  (`10.77.0.2`), avec une clé partagée en plus, ouvert par la maison
  (`PersistentKeepalive = 25`) : aucune redirection de port sur la box ; le VPS écoute
  en UDP 51820. `10.77.0` plutôt que `10.8.0`, pris par OpenVPN par défaut.
- **Démon** (`cpa-remote.service`) : `remote.py serve --spectateurs 10.77.0.1` : tout
  ce qui arrive du tunnel est en lecture seule (§ 9.1), quel que soit le réglage
  d'Apache, et ne peut pas se faire passer pour l'Oric.
- **Vitrine** (`cpa-vitrine.service`, § 9.5) sur la même machine, pour que les
  spectateurs voient quelque chose bouger. Disquette de démonstration en A:.
- **Apache** (`mod_proxy`, `mod_proxy_http`, certificat déjà en place sur le VPS),
  `cpa-oric.conf` inclus dans le `VirtualHost` HTTPS :

        RedirectMatch ^/cpa$ /cpa/
        <Location /cpa/>
            ProxyPass http://10.77.0.2:8040/ timeout=30 retry=5
            ProxyPassReverse http://10.77.0.2:8040/
            <LimitExcept GET HEAD>
                Require all denied
            </LimitExcept>
        </Location>
        <LocationMatch "^/cpa/(journal|version)">
            Require all denied
        </LocationMatch>

  `timeout=30` laisse passer l'attente longue de `/ecran` (5 s). La barre finale compte :
  les adresses de la page sont relatives. Essayé dans un Apache 2.4 local : page,
  redirection, 403 sur `POST` et `/journal`, 503 au-delà du plafond, page sans boutons.
- Pour laisser taper quelqu'un de confiance plus tard : un second chemin protégé par mot
  de passe, qui arrive au démon par une autre adresse que celle des spectateurs.

## 10. Lots

1. **`HOSTS` et appel du modem** (§ 8) : fait.
2. **Mesures** (sur le vrai Oric) : XFER de 7,8 Ko reçu en 5 à 10 s ; envoyé en moins de
   10 s depuis que `ac_txw` attend 5 s.
3. **Pilote, REMOTE et démon** : fait. `tools/test_remote.sh` (Oricutron, temps réel,
   ~6 min) : l'écran tenu par le démon est celui du vidage mémoire après DIR et un menu
   FUNCT, EDIT (2 Ko collés, `^S`, `^Q`, puis TYPE ; fichier identique au texte), CMDER,
   GRAPHER en SPLIT, `$FD 'B'` pendant CMDER (console toujours active), démon tué au
   milieu d'une réponse (l'Oric continue, puis rappelle un nouveau démon) ; refus de
   TERM et XFER, `REMOTE`, `REMOTE OFF`. Ce qu'Oricutron ne montre pas : le voyant `r`
   (son modem accepte toujours l'octet émis).
4. **Page web** (§ 9) : fait. Rendu comparé point par point à `oric_ecran.py`, touches
   et Coller essayés avec le faux démon (navigateur d'ordinateur et de téléphone
   simulés), page servie par le démon. Elle ne fait qu'afficher et envoyer ce que le
   démon du lot 3 sait déjà faire.
5. **Vitrine et spectateurs** (§ 9.5, § 9.6) : fait. Chaque scène jouée dans Oricutron
   par un démon local (programmes écrits dans EDIT identiques à l'octet près) ;
   spectateurs refusés (403) et page en lecture seule.

À vérifier sur le vrai Oric : `essais-materiel.md` (console à distance).

## 11. Questions ouvertes

Aucune. Écarté : une copie de tout ce qui passe par CONOUT vers le Mac (un journal) ;
l'écran suffit, et `PUT` capture déjà la sortie d'une commande dans un fichier.
