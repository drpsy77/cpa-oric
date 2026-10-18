# CP/A — vision

*My Oric back to life: create, develop and publish — all on the lovely little machine itself.*

## La phrase

Redonner l'envie de se servir de son Oric : créer et développer sur la machine elle-même,
avec l'aisance d'un système d'aujourd'hui, et faire tourner ce qu'on y crée sur n'importe
quel Oric.

## Pourquoi

Un Oric reste dans son armoire quand rien n'y est agréable. Le BASIC et son éditeur ont
vieilli, SEDORIC est difficile d'accès, les éditeurs et assembleurs de l'époque demandaient de
l'héroïsme. On développe alors sur le PC (OSDK) et on joue dans un émulateur : la machine ne
sert plus. Le LOCI a réglé le stockage ; il manquait un environnement qui donne envie de
s'asseoir devant l'Oric. CP/A est cet environnement : un système fluide, des outils qui
parlent la même langue, et tout ce qu'il faut pour créer sans quitter la machine.

## Pour qui

- D'abord le possesseur d'un Atmos avec un lecteur (LOCI, Cumulus, Microdisc) qui veut créer
  sur sa machine : jeux, dessins, programmes.
- Ensuite, par la sortie `.TAP`, tout possesseur d'un Oric : il reçoit ce qui a été créé
  sous CP/A et le charge depuis une cassette, sans avoir CP/A.

## Ce qui compte, dans cet ordre

1. **Tout sur la machine.** Écrire, dessiner, développer, compiler, lancer, sans passer par
   un PC. Le PC reste un atelier (construction, tests), jamais une étape obligée.
2. **Développer et compiler.** GRAPHER (interprété pour essayer, traduit en assembleur pour
   la vitesse) et ASM sont la plateforme : des jeux, mais pas seulement.
3. **Ouvert sur l'extérieur.** Clé USB, réseau par le modem WiFi du LOCI, et le pont vers
   l'Oric de base (`.TAP`, cassette).
4. **Le plaisir d'usage.** Mêmes touches partout, menus, complétion, historique, messages
   clairs : tout doit être simple à prendre en main.
5. **La sobriété.** Tout ajout résident se justifie, le reste va en `.COM` ; tout marche avec
   un seul lecteur.

## Ce que CP/A n'est pas

- Une suite bureautique : ni traitement de texte, ni tableur, ni base de données. EDIT reste
  un éditeur (programmes, scripts, données).
- Un CP/M à rattraper fonction par fonction : on prend de CP/M ce qui sert (zones
  utilisateur, IOBYTE : non).
- Un BASIC de plus : le pont va vers le BASIC de l'Oric, pas l'inverse.
- Un outil pour PC ou pour émulateur : le vrai Oric est la référence.

## La version 1.0

- **Atelier créatif** : dessin assisté (plus précis que la tortue de LOGO), éditeur de
  sprites et de caractères, tuiles.
- **GRAPHER plateforme** : un jeu complet écrit, dessiné, mis au point et traduit sur l'Oric
  (phases d'un jeu, tuiles).
- **Pont vers l'Oric de base** : un jeu fait sous CP/A se charge sur un Atmos sans lecteur,
  depuis une cassette (`MKTAP`, `CASSETTE`).
- **Extérieur** : transfert de fichiers et terminal par le modem WiFi du LOCI.
- Vérifiée sur le vrai matériel.

## Pour décider

Une idée entre dans la suite prévue (`docs/etat.md` § 2) si elle sert l'un des points 1 à 3
sans trahir les points 4 et 5. Ce qui ne sert aucun des trois attend, ou n'est pas fait.

## Questions ouvertes

- Au-delà de son auteur : CP/A est-il proposé à la communauté Oric (langue des messages et
  de la documentation, diffusion) ?
- La version ROM (`docs/projet-rom.md`) : quelle place dans la 1.0 ?
