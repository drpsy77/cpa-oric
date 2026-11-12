# CP/A — fausses bonnes idées

Idées examinées puis écartées, avec leurs raisons, pour ne pas les réétudier à chaque revue.
Une idée ne sort d'ici que si un fait nouveau retire l'une de ses raisons.

## Écriture différée du répertoire (ERA, REN, attributs)

**L'idée** : ERA, REN et SET réécrivent le secteur du répertoire après chaque entrée
modifiée. En gardant le secteur en mémoire pour ne l'écrire qu'une fois (en passant au
secteur suivant ou en fin de commande, comme le tampon à écriture différée de `src/fs.s`
le fait pour les données), on diviserait les écritures jusqu'à 8.

**Pourquoi non** :

- Le gain est rare : il faut que plusieurs entrées touchées soient dans le même secteur
  (jokers, ou fichier de plus de 16 Ko). Sur le LOCI, qui répond vite, l'attente évitée ne
  se voit pas.
- Le risque grandit : après un RESET, le démarrage à chaud réécrit le tampon s'il est
  marqué « modifié ». Une entrée en cours de modification (un nom à moitié changé par REN)
  partirait sur la disquette. S'en protéger coûte encore des octets résidents.
- Seul un vrai lecteur y gagnerait. Or le possesseur d'un vrai Microdisc garde le système
  qu'il connaît ; CP/A vise l'Oric muni d'un LOCI (`docs/vision.md`).
