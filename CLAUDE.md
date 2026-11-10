# CP/A — notes pour Claude

Mini système « à la CP/M » pour Oric Atmos (6502, assembleur `xa`). Le système est chargé
d'une disquette Microdisc dans la RAM overlay (`build/cpa.dsk`) ; la version ROM est abandonnée.
Au début de chaque conversation, lire **seulement** `docs/architecture.md` et `docs/etat.md`,
puis les documents et les sources utiles à la demande (index : `README.md`). Règles de
documentation : `docs/architecture.md` § 7.

## Contexte de travail

- Machine : Raspberry Pi 400 (machine de test) ou Mac. Pierre parle souvent depuis son téléphone
  (Remote Control) : réponses concises, en français, pas de longues sorties de terminal.
- Tout ce qui se construit reste dans le dépôt (`~/Projets/cpa-oric` sur le Pi,
  `~/Documents/GitHub/cpa-oric` sur le Mac).
- **Ne jamais proposer de retirer ou d'alléger les menus déroulants ni la complétion**
  (option `CPLCMD` comprise) : ce sont les fonctions phares (`docs/vision.md`) ; la place
  se cherche ailleurs.
- **Aucune action système** (sudo, apt, /etc, services, installation hors du projet) sans
  confirmation de Pierre que sa sauvegarde est faite. S'il manque un outil système : donner
  la commande, Pierre la lance.
- Ne pas toucher à l'Oricutron de Pierre (`~/Documents/Oric/oricutron-master`,
  `~/Documents/Oric/Oricutron`). Celui des tests est `tools/oricutron/` (sources officielles
  au commit de `tools/setup_linux.sh` + `tools/oricutron-testhook.patch`, ignoré par git).
- Référence : GitHub (`drpsy77/cpa-oric`, `gh` authentifié). Commits en français, proposés en
  fin de tâche ; **pas de push sans accord**.

## Construire

    ./tools/build_xa.sh        # une fois : compile xa dans tools/xa
    ./build.sh                 # système, .COM, disquettes ; erreurs dans build/*.err

Les images `build/*.dsk` ne sont pas versionnées (publiées par une version GitHub :
`git tag vX.Y`, `git push origin vX.Y`). Leurs sommes le sont (`build/disquettes.md5`) :
après `./build.sh`, `git status` montre si une image a changé.

## Tester

    tools/smoke_test.sh                                  # chaîne complète (avec Oricutron)
    tools/test_asm.sh                                    # ASM.COM == xa, octet par octet
    tools/test_inc.sh                                    # .INC allégés == originaux
    tools/test_lib.sh [NOM...]                           # GRX.LIB (#lib) == .INC, programmes traduits
    python3 tools/test_fs.py                             # fichiers : fin de fichier, ajout (6502 simulé)
    python3 tools/test_fp.py                             # décimaux de LOGO
    tools/test_logo.sh                                   # LOGO (long : ~20 min sur le Pi)
    DSK=build/cpa.dsk ORIC_KEYS_AT=400 tools/run_test.sh $'DIR\n' 900 /tmp/t
    python3 tools/screen.py /tmp/t.mem                   # écran texte du vidage

`run_test.sh` demande l'Oricutron avec `tools/oricutron-testhook.patch` (voir
`docs/atelier.md` § 2 et 4).
