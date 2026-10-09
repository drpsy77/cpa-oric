# Compresseur d'écran HIRES (LZSS) — archive

Fichiers écrits avec Claude dans un projet OSDK antérieur, gardés ici
**tels quels** en vue d'une reprise dans CP/A (backlog, point 7 de
`docs/projet-disquette.md`). Ils ne sont pas utilisés par la construction.

- `decode_screen_hires.s` : décodeur 6502 (xa, conventions OSDK :
  `tmp0`-`tmp2` en page zéro, `.bss`, labels `+` dans un bloc `.( .)`).
- `compress_hires.py` : compresseur et décompresseur de contrôle (Python 3,
  sans dépendance). `compress ecran.bin ecran.lz` vérifie l'aller-retour.

Format : groupes de 8 jetons précédés d'un octet de drapeaux (bit 0 en
premier). Bit à 1 : littéral, 1 octet. Bit à 0 : copie, distance 16 bits
little-endian puis longueur 4..255 ; copie octet par octet (recouvrements
permis). Pas de marqueur de fin : la taille de sortie (8 000 octets) est
connue des deux côtés.

Mesures (images faites avec `tools/png2hir.py`, 8 000 octets) :

| Image                                   | Compressé |
|-----------------------------------------|----------:|
| écran vide                              |     102   |
| copie d'écran texte (seuil)             | 1 150-1 330 |
| logo, seuil sans tramage                |   1 133   |
| logo, tramage Floyd-Steinberg           |   4 353   |

Le tramage casse les répétitions : une image tramée gagne environ moitié,
un dessin au trait ou un aplat 6 à 8 fois.
