# CP/A — édition Microdisc (branche `microdisc`)

Une démonstration : CP/A et LOGO sur un Oric Atmos muni d'un contrôleur Microdisc et de son
lecteur simple face, sans rien d'autre. Elle part du code du 31 octobre 2026 (dernier état
à la géométrie de SEDORIC, 42 pistes de 17 secteurs) et n'évolue pas avec la branche `main`.

- **Disquettes** : `build/cpa-logo-md.dsk` (français) et `build/cpa-logo-md-en.dsk`
  (anglais), autonomes et amorçables : une face de 42 pistes (image de 269 Ko), 156 Ko pour
  les fichiers, 74 Ko libres. Dessus : LOGO et ses exemples, EDIT, HELP, VOIR et les
  commandes de base (TYPE, ERA, REN, SET, STAT, COPY, FORMAT, DISKCOPY, XDO).
- **Retiré** : tout ce qui échange avec l'extérieur ou dépend du LOCI (EXPORT, IMPORT,
  USBDIR, USBMOUNT, TERM, XFER, MKTAP, le contrôle du LOCI dans le pilote disque), ainsi
  que CMDER, LOGOTR, GRAPHER et les outils d'assembleur. L'imprimante (port Centronics)
  reste.
- **Ce qui change dans le code** : `src/hw.inc` (une face, 714 secteurs, 80 blocs de 2 Ko),
  `src/disk.s` (piste logique = cylindre, face 0), `boot/boot.s`, `progs/format.s`,
  `progs/diskcopy.s`, `progs/stat.s`, `tools/mkdisk.py`, `build.sh` (ces deux disquettes
  seulement), `tools/gen_readme_txt.py` (aide réduite aux programmes présents).
- **Essayé** dans Oricutron seulement (Atmos, contrôleur Microdisc, image simple face) :
  démarrage, `DIRS`, `STAT`, `HELP`, `LOGO DEMO`, `SAUVE`, `FORMAT B:`, `COPY` vers B:,
  `DISKCOPY A: B:` ; images vérifiées par `tools/mkdisk.py check`. **Jamais essayé sur un
  vrai Microdisc** : qui en a un est le bienvenu pour le dire (une issue sur le dépôt).
- Ces disquettes ne sont pas lues par CP/A de la branche `main` (2 faces de 80 pistes), ni
  l'inverse.

---

**CP/A — Microdisc edition.** A demonstration: CP/A and LOGO on an Oric Atmos with a
Microdisc controller and its single-sided drive, nothing else. Built from the code of
31 October 2026 (SEDORIC geometry, 42 tracks of 17 sectors), frozen. Disks:
`cpa-logo-md-en.dsk` (English) and `cpa-logo-md.dsk` (French), bootable, one side of 42
tracks, 74 KB free: LOGO and its examples, EDIT, HELP, VOIR and the basic commands. No USB
stick, no modem, no LOCI. Tried in Oricutron only — never on a real Microdisc: reports are
welcome (open an issue).
