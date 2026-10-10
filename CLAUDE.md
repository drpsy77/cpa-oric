# CP/A — notes pour Claude

Mini système « à la CP/M » pour Oric Atmos (6502, assembleur `xa`). Deux variantes des mêmes
sources : `build/cpa.dsk` (disquette Microdisc, système en RAM overlay) et `build/cpa.rom`.
À lire : `README.md`, `docs/architecture.md`, `docs/atelier.md` ; état et lots prévus dans
`docs/projet-disquette.md` (« Suite prévue »).

## Contexte de travail

- Machine : Raspberry Pi 400 (machine de test). Pierre parle souvent depuis son téléphone
  (Remote Control) : réponses concises, en français, pas de longues sorties de terminal.
- Tout ce qui se construit reste dans `~/Projets/cpa-oric`.
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
    ./build.sh                 # ROM, système disque, .COM, disquettes ; erreurs dans build/*.err

Les images `build/*.dsk` et `build/cpa.rom` sont versionnées : après `./build.sh`, `git status`
montre si elles ont changé.

## Tester

    tools/smoke_test.sh                                  # chaîne complète (avec Oricutron)
    tools/test_asm.sh                                    # ASM.COM == xa, octet par octet
    python3 tools/test_fp.py                             # décimaux de LOGO
    tools/test_logo.sh                                   # LOGO (long : ~20 min sur le Pi)
    DSK=build/cpa.dsk ORIC_KEYS_AT=400 tools/run_test.sh $'DIR\n' 900 /tmp/t
    python3 tools/screen.py /tmp/t.mem                   # écran texte du vidage

`run_test.sh` demande l'Oricutron avec `tools/oricutron-testhook.patch` (voir
`docs/atelier.md` § 2 et 4).
