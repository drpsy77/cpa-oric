# L'atelier : construire et tester CP/A comme Claude

Ce document décrit comment Claude travaille sur CP/A et comment refaire la même chose sur le
Raspberry Pi 400. Il dit aussi à quoi sert chaque machine.

## 1. Quelle machine pour quoi

| Machine | Rôle | Pourquoi |
|---|---|---|
| **Raspberry Pi 400** | atelier complet : construction, tests automatiques, émulateur piloté par script | c'est un Linux, comme l'environnement de Claude : les mêmes scripts y tournent sans adaptation |
| **Windows 11 (UTM)** | jouer avec CP/A dans Oricutron, à la main | ton usage habituel ; aucun outil à ajouter |
| **Mac** | éditer, `git`, lien avec Claude ; jouer avec CP/A dans Oricutron pour Mac (§ 5 bis) | Oricutron est compilé par GitHub, rien à compiler sur le Mac |
| **iPhone, iPad** | jouer avec CP/A dans Oricutron pour le web (§ 5 ter) | page publiée par GitHub Pages, ROMs gardées dans le navigateur |
| **Oric Atmos + LOCI** | essai final sur le vrai matériel | timing, son et écran réels |

Les fichiers circulent par GitHub : `git push` depuis une machine, `git pull` sur une autre.
Les images prêtes à l'emploi (`build/cpa.dsk`, `build/cpa.rom`) sont dans le dépôt : Windows et
le LOCI n'ont donc jamais besoin de construire quoi que ce soit.

## 2. Comment Claude travaille

Claude n'a ni écran ni clavier d'Oric. Il travaille dans un Linux sans affichage, avec quatre
outils, et suit toujours la même boucle.

### Les outils

1. **`xa`** (l'assembleur de l'OSDK), compilé depuis ses sources. `./build.sh` assemble la ROM,
   le système disque, l'amorce et les programmes `.COM`, puis fabrique la disquette avec
   `tools/mkdisk.py`. Le script contrôle aussi les tailles (ROM de 16 Ko, système disque qui
   s'arrête avant `$F670`, page `$FF00` qui n'atteint pas les vecteurs).
2. **Oricutron modifié** (`tools/oricutron-testhook.patch`, surtout dans `main.c`). Le
   correctif lit des variables d'environnement à chaque trame (1/50 s) :
   - `ORIC_KEYS` : texte tapé touche par touche, comme sur le clavier de l'Oric (les caractères
     obtenus avec SHIFT, comme `" + ( ) < > ? $ *`, sont tapés avec SHIFT) ;
   - `ORIC_KEYS_AT` : trame où la frappe commence ;
   - `ORIC_DUMP` / `ORIC_DUMP_AT` : fichier et trame du vidage des 64 Ko de mémoire.
   - `ORIC_PASTE` / `ORIC_PASTE_AT` : texte collé comme par F12, et trame du collage.

   Il change aussi le collage du presse-papiers (F12) : d'origine, Oricutron ne livre le texte
   qu'à la routine clavier de la ROM BASIC (adresse `$EB78`), que CP/A n'utilise pas. Le texte
   est maintenant tapé sur la matrice du clavier simulé (tables de `src/tables.s`), environ 15
   caractères par seconde (touche 2 trames enfoncée, 1 relâchée ; SHIFT une trame avant), ce qui
   marche avec tout logiciel. En CP/A disquette (ROM masquée),
   le collage tient compte du verrouillage des majuscules (`$021A`) pour garder la casse.
   Enfin, le jaune de la palette est adouci (`#FFF426` au lieu de `#FFFF00`), plus lisible sur fond blanc.
   Sur le clavier dessiné (« Show keyboard »), une touche reste enfoncée 3 trames au moins, et
   SHIFT, CTRL, FUNCT collantes sont relâchées avec elle : un toucher bref sur un écran tactile
   est vu par CP/A, qui lit le clavier à 50 Hz.

   L'émulateur tourne dans un écran virtuel (Xvfb), sans son.
3. **`tools/screen.py`** lit l'écran texte (`$BB80`) dans le vidage et l'affiche en texte. Claude
   « voit » ainsi l'écran : les menus, le prompt, les messages d'erreur. Une capture PNG sert
   quand il faut regarder les couleurs ou les graphismes.
4. **`tools/run_com.py`** exécute un `.COM` dans un 6502 simulé en Python (module `py65`), avec un
   petit BDOS qui lit et écrit les fichiers d'un dossier du PC. Il sert pour les programmes sans
   écran, surtout ASM.COM : `tools/test_asm.sh` assemble chaque programme de `progs/` avec ASM.COM
   puis avec `xa`, et compare les octets.

### La boucle

1. Lire les sources et la table des symboles (`build/cpa_sys.sym` : `f4bf rom_end`).
2. Modifier les sources, puis lancer `./build.sh`. Une erreur d'assemblage s'affiche dans
   `build/*.err`.
3. Écrire un scénario de frappe, lancer l'émulateur, lire l'écran à la trame voulue.
4. Si le résultat est faux, lire des variables dans le vidage (adresses dans `.sym`), corriger,
   puis recommencer à l'étape 2.
5. Relancer les tests des livraisons précédentes (non-régression), puis faire un commit.

Exemple réel : vérifier que `TYPE README.TXT` met bien en pause en fin d'écran, que `^C`
interrompt, et que le prompt revient :

    DSK=build/cpa.dsk ORIC_KEYS_AT=400 tools/run_test.sh \
      $'TYPE README.TXT\n|\x1cC' 900 /tmp/t
    python3 tools/screen.py /tmp/t.mem

Dans cet exemple, `|` attend 3 s (le temps que la pause s'affiche) et `\x1cC` tape CTRL-C.

### Ce que cette méthode ne voit pas

- **Le son** : l'émulateur tourne sans audio. Claude vérifie seulement la logique (registres,
  durées) ; l'oreille, c'est toi sur le vrai Oric.
- **Le timing réel** du lecteur de disquettes et du LOCI.
- **Le rendu des couleurs** sur un vrai écran : les captures donnent une idée, sans plus.

D'où les essais sur matériel notés dans `docs/projet-disquette.md`.

## 3. Installer l'atelier sur le Raspberry Pi 400

Une seule commande installe tout **dans le dépôt** (`tools/xa`, `tools/pylib/`,
`tools/oricutron/`, tous ignorés par git). Ton Oricutron déjà compilé n'est pas modifié.

    git clone https://github.com/drpsy77/cpa-oric.git cpa-oric
    cd cpa-oric
    ./tools/setup_linux.sh ~/chemin/vers/ton/oricutron/roms

Le script fait quatre choses, et peut être relancé (il ne refait que ce qui manque) :

1. Il installe les paquets manquants avec `apt` (le mot de passe `sudo` est demandé) : `git`,
   `build-essential`, `cmake`, `libsdl2-dev`, `python3`, `python3-pip`, `xvfb`, `imagemagick`.
2. Il compile `xa` depuis les sources de l'OSDK (`tools/build_xa.sh`).
3. Il installe `py65` dans `tools/pylib` (pas dans le Python du système).
4. Il compile Oricutron, à la même version que Claude et avec le correctif de test, puis copie
   `basic11b.rom` et `microdis.rom` depuis le dossier indiqué. Ces deux ROM ne sont pas fournies
   avec les sources d'Oricutron. Sans argument, le script les cherche dans ton dossier personnel.

Ensuite, la vérification complète :

    tools/smoke_test.sh

Le script construit tout, démarre la disquette et tape `DIR`, démarre la ROM et tape `VER`,
affiche les deux écrans et finit par « OK : l'atelier fonctionne ».

Cette procédure a été essayée de bout en bout sur un Linux vierge (Ubuntu 24.04 sur PC). Sur le
Pi, seules les durées changent : comptez quelques minutes pour compiler Oricutron, et plusieurs
minutes pour `test_asm.sh` (environ 1 min 20 s sur le PC de Claude) et `test_logo.sh` (environ
20 min ; `run_test.sh` attend l'émulateur 5 min au plus).

Quand le correctif de test change (`tools/oricutron-testhook.patch`), il faut recompiler
Oricutron : supprimer `tools/oricutron/` puis relancer `./tools/setup_linux.sh`.

## 4. Les commandes de l'atelier

| Commande | Rôle |
|---|---|
| `./build.sh` | construit `build/cpa.rom`, `build/cpa.dsk`, `build/progs/*.COM` et les `.sym` |
| `tools/smoke_test.sh` | vérifie toute la chaîne (construction + émulateur) |
| `tools/test_asm.sh` | ASM.COM doit redonner exactement les octets de `xa` |
| `python3 tools/test_fp.py [n]` | `progs/fp_inc.s` (décimaux) dans un 6502 simulé, comparé à un calcul exact |
| `tools/test_logo.sh` | LOGO.COM : scénarios `tools/logo_tests/*.log` comparés aux `.ref` (texte, images) ; `REF=1` réécrit les références |
| `tools/run_test.sh TOUCHES TRAME SORTIE` | émulateur piloté : frappe, vidage, capture |
| `python3 tools/screen.py SORTIE.mem` | écran texte du vidage |
| `python3 tools/run_com.py DOSSIER PROG.COM args` | `.COM` dans un 6502 simulé (BDOS minimal) |
| `python3 tools/mkdisk.py ls IMAGE` | contenu d'une disquette |
| `python3 tools/mkdisk.py get IMAGE NOM.EXT [local]` | extraire un fichier (ex. un `.ASM` écrit sur l'Oric) |
| `python3 tools/mkdisk.py put IMAGE local [NOM.EXT]` | ajouter un fichier |
| `python3 tools/mkdisk.py era IMAGE NOM.EXT` | effacer un fichier |
| `python3 tools/gen_readme_txt.py` | régénère README.TXT et la table de HELP.COM |

### `run_test.sh` en détail

    tools/run_test.sh TOUCHES TRAME SORTIE [options d'Oricutron]

- **TOUCHES** : à écrire avec `$'...'` dans bash pour les codes spéciaux.

  | Code | Touche |
  |---|---|
  | `\n` | Entrée |
  | `~` | DEL |
  | `\x1b` | ESC |
  | `\x01` `\x02` `\x03` `\x04` | flèches gauche, droite, haut, bas |
  | `\x05` | FUNCT (ouvre la barre de menus) |
  | `\x1c` puis une lettre | CTRL + lettre (`\x1cC` = ^C) |
  | `\x06` | bouton RESET (NMI) |
  | `\|` | pause de 3 s dans la frappe |

  Majuscules et `$ : * # " > < ( )` sont tapés avec SHIFT automatiquement. L'Oric démarre en
  majuscules (voyant `A`) : une minuscule s'affiche en majuscule et une majuscule (avec SHIFT) en minuscule. Pour les
  commandes, cela ne change rien ; pour du texte, tape en minuscules.
- **TRAME** : instant du vidage (50 trames par seconde). L'émulateur s'arrête juste après.
- **SORTIE** : préfixe des résultats `SORTIE.mem` (64 Ko), `SORTIE.png`, `SORTIE.log`.

Variables utiles :

| Variable | Effet |
|---|---|
| `DSK=build/cpa.dsk` | démarre sur la disquette. Elle est copiée, car Oricutron réécrit l'image : l'original ne change pas |
| `ORIC_KEYS_AT=400` | début de la frappe : 400 pour la disquette (environ 6 s de démarrage), défaut 100 pour la ROM |
| `ORIC_ROM=cpa` | démarre sur `build/cpa.rom` au lieu de la ROM BASIC 1.1 |
| `SHOW=1` | **affiche la fenêtre** sur le bureau du Pi au lieu de l'écran virtuel : pratique pour regarder un scénario se dérouler |

Points à connaître :

- Les touches tapées avant la fin du démarrage sont perdues. Si l'écran ne montre pas ta
  commande, retarde `ORIC_KEYS_AT`.
- Dans le vidage, `$0300-$03FF` (entrées-sorties) vaut zéro. La zone `$C000-$FFFF` montre ce que
  le processeur voit au moment du vidage : la RAM overlay pour la version disquette.
- Pour lire une variable :
  `python3 -c "m=open('/tmp/t.mem','rb').read(); print(hex(m[0x280]))"` (ici `vmode`, adresse
  prise dans `build/cpa_sys.sym`).

### Exemples

    # menu Ecran > Mode SPLIT, puis un cercle
    DSK=build/cpa.dsk ORIC_KEYS_AT=400 tools/run_test.sh \
      $'\x05\x02\x02\x04\n|CIRCLE 120 64 40\n' 900 /tmp/g
    # (regarder /tmp/g.png pour le graphisme)

    # un script DO avec un paramètre ($1 = le texte affiché par GTEXT)
    DSK=build/cpa.dsk ORIC_KEYS_AT=400 tools/run_test.sh $'DO DESSIN bonjour\n' 1500 /tmp/s

    # un programme hors émulateur : ASM.COM assemble HELLO.ASM
    mkdir /tmp/a && cp build/progs/ASM.COM /tmp/a && cp progs/hello.s /tmp/a/HELLO.ASM \
      && cp progs/cpa.inc /tmp/a/CPA.INC
    (cd /tmp/a && python3 ~/cpa-oric/tools/run_com.py /tmp/a ASM.COM hello)
    # affiche « HELLO.COM $0500-$0557 : 88 octets » ; HELLO.COM et HELLO.SYM sont dans /tmp/a

## 5. Windows 11 : jouer avec le résultat

Rien à construire : les images sont dans le dépôt.

1. Récupérer `build/cpa.dsk` et `build/cpa.rom` : `git pull` si Git est installé sous Windows,
   sinon le bouton de téléchargement de chaque fichier sur Codeberg, ou une copie depuis le Pi.
2. **Version disquette** : dans Oricutron, machine Atmos, contrôleur Microdisc, insérer
   `cpa.dsk`, puis RESET.
3. **Version ROM** : copier `cpa.rom` dans le dossier `roms` d'Oricutron et choisir cette ROM à
   la place de `basic11b` (fichier `oricutron.cfg` : `atmosrom = 'roms/cpa'`). Pense à remettre
   `basic11b` ensuite.

Le correctif de test n'est pas nécessaire sous Windows pour les scénarios automatiques, qui
tournent sur le Pi ; sans lui, le collage F12 ne marche pas dans CP/A.

## 5 bis. Mac : Oricutron compilé par GitHub

Le fichier `.github/workflows/oricutron-macos.yml` fait compiler par GitHub, sur un Mac Apple
Silicon, Oricutron à la même version que les tests, avec le correctif ci-dessus (donc le
collage F12 qui marche dans CP/A) et SDL2 inclus dans l'application. Il se lance quand le
correctif ou ce fichier change, ou à la main (onglet Actions, « Oricutron macOS », Run
workflow). L'archive se télécharge dans l'onglet Actions, dernière exécution, artefact
`Oricutron-CPA-macOS`. Mode d'emploi : `tools/LISEZMOI-mac.txt`, copié dans l'archive (les
ROMs `basic11b.rom` et `microdis.rom` sont à ajouter, l'application n'étant pas signée il faut
lever la quarantaine au premier lancement). Le rendu logiciel est réglé par défaut
(`rendermode = soft`) : avec SDL2, Oricutron demandait la surface de la fenêtre avant de créer
le contexte OpenGL, ce qui plante sous macOS (`glMatrixMode` sur un contexte nul) ; le
correctif inverse l'ordre sur Mac. Essayé par Pierre : les deux rendus (soft et opengl) et le
collage F12 marchent.

## 5 ter. iPhone : Oricutron pour le web

`.github/workflows/oricutron-web.yml` compile Oricutron avec Emscripten (même version, même
correctif, compilé avec `-DWWW -DCPA_WWW`) par `tools/web/build_web.sh`, et publie le site sur
GitHub Pages : https://drpsy77.github.io/cpa-oric/ (et dans l'artefact `Oricutron-CPA-web`).
La page (`tools/web/shell.html`) :

- ne publie aucune ROM : elle les demande au premier lancement (choix dans Fichiers, reconnues
  à leur taille) et les garde, avec la disquette, dans `/readwritefs`, monté sur IndexedDB et
  relu **avant** le démarrage de l'émulateur (Module.preRun) ;
- démarre sur `cpa.dsk`, copiée depuis `build/cpa.dsk` à la première visite ; ce que CP/A
  écrit est gardé (`diskautosave`, puis `FS.syncfs`) ;
- affiche le clavier dessiné de l'Atmos (`show_keyboard`), touches collantes ;
- ajoute des boutons : Coller (fonction `cpa_www_paste`), RESET (`cpa_www_reset`, NMI),
  Ouvrir / Enregistrer la disquette (`cpa_www_flush` écrit d'abord ce qui est en attente ;
  sur iPhone, feuille de partage « Enregistrer dans Fichiers »), CP/A d'origine.

Mode d'emploi : `tools/web/LISEZMOI-web.txt`. Essayé dans Chromium en mode iPhone 13 : choix des
ROMs, démarrage, frappe au doigt (touchers brefs, SHIFT collant, lettres doublées), collage,
enregistrement, rechargement (ROMs et disquette retrouvées). Pour compiler chez soi, il faut
Emscripten ; sans accès direct à GitHub pour ses « ports », `EMCC_LOCAL_PORTS=sdl2=<SDL2>`.

## 6. Ce qui ne se trouve que chez Claude

Rien d'indispensable. Claude a en plus le lien avec ton Mac (copie des fichiers, commits dans
`~/Projets/cpa-oric`). Sur le Pi, tu as tout ce qu'il utilise pour construire et tester.
