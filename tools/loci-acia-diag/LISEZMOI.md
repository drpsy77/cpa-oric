# LOCI 0.3.98 « acia-diag » — sonde pour l'ACIA en $0380

Firmware de **diagnostic**, pas un correctif. Il sert à savoir *où* casse la
lecture de l'ACIA (`TERM /D` lit `A7 4C D0` au lieu de `70 02 00`).

## Ce que c'est

- Les sources de la 0.3.1 (dépôt `sodiumlb/loci-firmware`, branche `main`, rien
  d'autre de changé côté disque, cassette, menus), avec la ROM du LOCI 0.3.0
  recompilée et intégrée. Le menu du LOCI affiche **0.3.98**.
- `CONFIG.SYS` n'est pas touché (même format que la 0.3.1) : réglages et
  minutages conservés. Les ROM BASIC et Microdisc déjà rangées dans la mémoire
  interne du LOCI par la 0.3.1 restent utilisées.
- Compilé ici avec GCC 13 et newlib-nano (la chaîne de l'auteur n'est pas
  connue). C'est la seule vraie différence avec la 0.3.1 officielle.

## Ce qui est ajouté (lecture seule pour l'Oric)

| Adresse | Contenu |
|---|---|
| `$0384-$0387` | motif fixe `A5 5A 0F F0` |
| `$0344-$0347` | même motif (autre zone de la page 3) |
| `$0388` | nombre de lectures de `$0381` vues par le LOCI (modulo 256) |
| `$0389` | nombre d'écritures dans `$0380-$0383` vues par le LOCI |
| `$038A` / `$038B` | dernier octet écrit en `$0382` / `$0383`, tel que vu sur le bus |
| `$038C` | bit 0 : modem (Pico) monté ; bit 1 : DTR actif |
| `$038D` | `$D1` : marque de ce firmware |

Le motif ne passe par aucun code de l'ACIA : s'il se lit bien, le chemin de
lecture du bus en `$038x` marche, et le défaut est dans l'émulation de l'ACIA.

## Installer, revenir en arrière

Par la même procédure que pour installer la 0.3.1, avec
`loci-0.3.98-acia-diag.uf2` à la place du `.uf2` officiel. Pour revenir :
réinstaller le `.uf2` de la 0.3.1. Rien d'autre à défaire (le `.uf2` n'écrit
que le début de la mémoire flash, pas la zone des fichiers du LOCI).

Si quoi que ce soit se comporte autrement qu'avec la 0.3.1 (menu, disquettes,
BASIC absent du menu), arrêter là et revenir à la 0.3.1 : c'est une
information en soi (chaîne de compilation), à me rapporter.

## Essais (dans cet ordre)

1. **BASIC, sans le Pico.** Monter `ACIADIAG.TAP` comme cassette, démarrer le
   BASIC, `CLOAD""` : le programme se lance seul. Photographier l'écran.
2. **BASIC, avec le Pico** (configuré, WiFi connecté) : même chose.
3. **CP/A, avec le Pico** : `DEBUG`, puis `D 0380` et `D 0340` (photo), puis
   `TERM /D`.

## Lire le résultat

| Observé | Conclusion |
|---|---|
| `38D` ≠ `D1` | ce n'est pas ce firmware qui tourne |
| motif `384` juste, ACIA `381-383` faux | lecture du bus correcte : défaut dans l'émulation de l'ACIA (firmware) |
| motif `384` faux, motif `344` juste | la zone `$038x` seule est perturbée : déplacer l'ACIA (piste `$0340` de l'auteur) |
| les deux motifs faux | lectures du LOCI hors `$031x` / `$03Ax` fausses : minutage ou matériel |
| lectures vues ≠ 10 ou écritures vues ≠ 2 | le LOCI ne voit pas (ou mal) les accès de l'Oric |
| `38A 38B` ≠ `B 1E` | les octets écrits arrivent faux sur le bus |
| tout juste en BASIC, faux sous CP/A | c'est l'environnement CP/A (RAM overlay, ROM coupée) qui gêne |

Valeurs attendues si tout va bien : ACIA *avant* `70 2 0` ; *après*
`10 B 1E` avec le Pico (`50 B 1E` sans), bit 7 (`90`, `D0`) possible.

## Fichiers

- `loci-0.3.98-acia-diag.uf2` : le firmware.
- `ACIADIAG.TAP`, `ACIADIAG.BAS` : le programme d'essai (fait par
  `tools/mktap.py` de CP/A).
- `loci-acia-diag.patch` : les modifications, par rapport à `main`.
