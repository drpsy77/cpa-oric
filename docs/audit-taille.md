# Audit de taille — CP/A (13 octobre 2026)

Mesures faites sur le commit `4aac5a4`, après `./build.sh` (images identiques à
celles du dépôt : `git status` propre). Aucun source modifié.

## 1. Constat principal

**L'octet gagné dans le code ne libère presque jamais de place sur la disquette.**
Le système de fichiers alloue par **blocs de 2 Ko** (`src/fs.s`, `tools/mkdisk.py`) :
un fichier ne rend un bloc que s'il repasse sous un multiple de 2 048 octets.
Sur `cpa.dsk`, 27 fichiers sur 41 font 2 Ko au plus et occupent déjà un seul
bloc : les optimiser ne rapporte rien.

Ce qui pèse, ce sont les **textes** et l'**arrondi des blocs**, pas le code :

| `cpa.dsk` (190,4 Ko de données, 236 Ko occupés, 100 Ko libres) | Ko |
|---|---:|
| Programmes .COM (hors HELP) | 87,5 |
| Sources .INC livrées (HIRES, GRX, ANIM, CPA) | 60,1 |
| HELP.COM (99 % de texte) | 18,5 |
| README.TXT | 18,4 |
| Autres fichiers (exemples, .GRX, .LOG, EDIT.CFG) | 5,9 |
| **Perte d'arrondi aux blocs de 2 Ko** | **45,6** |

Le système lui-même occupe une zone fixe de 16 Ko (secteurs 3 à 66) : réduire
son code ne libère rien sur la disquette. En revanche, il est **à l'étroit en
RAM** : le code disque s'arrête en `$F599`, **215 octets** avant les zones de
travail (`$F670`), et la page `$FF00` n'a que 66 octets de marge.

## 2. Propositions classées par gain

> **Suivi (13 octobre 2026) : A1, A2 et A3 sont faits.** Place libre mesurée après
> `./build.sh` : `cpa.dsk` 100 → **164 Ko**, `cpa-logo` 198 → 208, `cpa-notes`
> 264 → 274, `cpa-asm` 154 → **200**, `cpa-anim` 116 → **162**. HELP.COM : 18 901
> → 9 173 octets (10 → 5 blocs), textes identiques à l'écran rubrique par
> rubrique (`tools/run_com.py`) ; décodage d'au plus ~0,7 s pour la dernière
> rubrique, compensé par 40 secteurs de moins à lire. README.TXT : 415 octets.
> .INC allégés : `tools/strip_inc.py`, contrôlés par `tools/test_inc.sh`
> (xa et ASM.COM, binaires identiques). Choix faits : espaces simples plutôt
> que TAB (plus petit, et EDIT n'a rien à apprendre) ; une ligne d'en-tête
> renvoie aux sources du dépôt.

Gains simulés à partir des répertoires réels des cinq disquettes.

### A. Fichiers texte — le gros du gain, peu de risque

**A1. Livrer des .INC sans commentaires (et indentés par TAB).**
ASM.COM ignore les commentaires et convertit déjà TAB en espace
(`progs/asm.s`, lecture de ligne) : rien à changer dans l'assembleur.

| fichier | aujourd'hui | sans commentaires + TAB |
|---|---:|---:|
| HIRES.INC | 26 409 o (13 blocs) | 11 446 o (6 blocs) |
| GRX.INC | 20 729 o (11 blocs) | 10 029 o (5 blocs) |
| ANIM.INC | 8 768 o (5 blocs) | 3 358 o (2 blocs) |
| CPA.INC | 5 492 o (3 blocs) | 1 565 o (1 bloc) |

**−36 Ko** sur `cpa.dsk`, `cpa-asm.dsk` et `cpa-anim.dsk`. Les sources
commentées restent dans le dépôt ; une étape de `build.sh` produit les copies
allégées. À décider : garder ou non l'en-tête qui liste les routines (la
documentation de la bibliothèque sur l'Oric), et vérifier qu'EDIT affiche
correctement un TAB.

**A2. README.TXT fait double emploi avec HELP.COM.**
98 % de ses lignes (18 398 octets sur 18 799) sont aussi dans HELP.COM : les
deux sont générés par `tools/gen_readme_txt.py`. Le retirer (ou le remplacer
par trois lignes « tapez HELP ») : **−20 Ko** sur `cpa.dsk`.

**A3. Compresser les textes de HELP.COM.**
Avec le LZSS du projet (`tools/lzhir.py`, même format que `archives/lzss-osdk`),
les 18 772 octets de texte tombent à environ 9 000 ; avec un décodeur d'une
centaine d'octets, HELP.COM passe de 10 à 5 blocs. HELP fait partie des
commandes de base : **−10 Ko sur chacune des cinq disquettes**.

### B. Programmes proches d'un seuil de bloc — gain ciblé

Octets à gagner pour rendre un bloc, et marge avant d'en prendre un de plus :

| .COM | taille | blocs | à gagner pour −1 bloc | marge avant +1 bloc |
|---|---:|---:|---:|---:|
| GRAPHER | 12 427 | 7 | **139** | 1 909 |
| DEBUG | 6 496 | 4 | **352** | 1 696 |
| HELP | 18 901 | 10 | 469 (voir A3) | 1 579 |
| LOGO | 18 950 | 10 | **518** | 1 530 |
| CMDER | 13 528 | 7 | 1 240 | 808 |
| EDIT | 8 192 | 4 | 2 048 | **0** |
| ASM | 5 949 | 3 | 1 853 | **195** |
| HEX | 3 840 | 2 | 1 792 | **256** |

- **GRAPHER (−2 Ko, 4 disquettes).** 175 octets de tampons `.dsb` (`sfcb`,
  `ifcb`, `par_*`, `word`, `kw`, `cname`, `numbuf`, `ofcb`…) sont stockés dans
  le fichier ; les déplacer après `h_free`, comme les autres tampons, suffit
  (12 252 octets). À vérifier : qu'aucun ne compte sur sa mise à zéro au
  chargement.
- **DEBUG (−2 Ko, 2 disquettes).** 122 octets de tampons à sortir du fichier,
  32 appels `lda #< / ldy #> / jsr puts` à passer en chaîne en ligne (4 octets
  chacun), chaînes terminées par le bit 7 (34) : environ 290 octets, le reste
  par factorisation.
- **LOGO (−2 Ko, 2 disquettes).** 33 `jmp error` précédés de leur pointeur
  (132 octets avec des messages en ligne), 188 chaînes terminées par 0 (bit 7 :
  188 octets), et 1,2 Ko de séquences de code répétées à l'identique (≥ 10
  octets) à factoriser en partie.
- **CMDER.** 1 240 octets à trouver : possible (108 appels avec pointeur,
  111 chaînes, ~970 octets de code répété) mais c'est une vraie campagne.
- **EDIT, ASM, HEX : zone rouge.** EDIT fait exactement 8 192 octets : le
  moindre ajout coûte 2 Ko. Il stocke 842 octets de zéros (tampons `recbuf`,
  `cline`, `fcb_cfg`… et l'alignement de page final) qu'on peut sortir du
  fichier pour se donner de la marge. HEX stocke 432 octets de zéros, XDO 512.

Simulation de A1 + A2 + A3 + B (GRAPHER, LOGO, DEBUG) :

| disquette | libres aujourd'hui | après |
|---|---:|---:|
| cpa.dsk | 100 Ko | **172 Ko** |
| cpa-logo.dsk | 198 Ko | 212 Ko |
| cpa-notes.dsk | 264 Ko | 274 Ko |
| cpa-asm.dsk | 154 Ko | **204 Ko** |
| cpa-anim.dsk | 116 Ko | **164 Ko** |

### C. Système — de la marge en RAM, pas de la place disque

- **Table `g_xbit` (`src/tables.s`).** 240 octets qui répètent 40 fois les
  mêmes 6 masques ; un seul endroit l'utilise (`src/gfx.s`, tracé d'un point
  en SPLIT). La remplacer par 6 octets et un calcul de `x mod 6` à partir de
  `g_xcol` : **environ +220 octets**, au prix de quelques cycles par point.
- **Police (`src/font.s`).** 768 octets dont seuls 5 bits par octet servent
  (bits 1 à 5) : regroupée sur 5 octets par caractère (480 octets) et dépliée
  par `font_init`, **environ +250 octets**. À vérifier : le tracé de texte de
  `gfx.s` lit `font_data` directement ; il faudrait lire la police déjà
  recopiée dans la RAM du jeu de caractères.
- **Code répété.** Environ 500 octets de séquences identiques (≥ 10 octets)
  hors tables, par exemple entre `g_box` et `g_line`, `go` et `f_delete`,
  `cmd_put` et `run_transient`. Gain réel plus faible (coût du `JSR`/`RTS`).

Les deux premiers points font passer la marge du système disque d'environ 215
à 680 octets, sans toucher au format des disquettes.

### D. Plus tard, si la place manque encore

- **Blocs de 1 Ko** : −27 Ko sur `cpa.dsk` (−22, −8, −18, −16 sur les autres).
  Mais 340 blocs n'entrent plus dans des numéros sur 8 bits : format de
  répertoire à changer, anciennes disquettes illisibles, et du code en plus
  dans un système qui n'a que 215 octets de marge. Seulement après C.
- **Opcodes non documentés** : quelques octets ici ou là (`LAX`, `DCP`,
  `SBX`), à n'utiliser que pour franchir un seuil précis. xa ne les connaît
  pas (macros `.byt`), et il faut vérifier Oricutron et le banc de test.

## 3. Ce que l'audit ne montre pas

- Le code est déjà soigné : 3 `JSR` suivis de `RTS` seulement dans tout le
  projet (CMDER, GRAPHER, HELP), par exemple. Une campagne de micro-optimisation générale coûterait cher pour
  peu de blocs ; elle ne se justifie que sur les fichiers proches d'un seuil
  (tableau B).
- Les estimations de B et C sont des ordres de grandeur, à confirmer par le
  build : seule la taille réelle après assemblage compte.

## 4. Méthode proposée

1. A1, A2, A3 d'abord : changements dans les outils de build, pas dans le
   code 6502 qui tourne déjà sur le vrai Oric.
2. Puis GRAPHER (tampons), DEBUG, LOGO, un commit par programme, avec la taille
   avant/après dans le message.
3. Chaque étape passe `tools/smoke_test.sh`, `tools/test_asm.sh` (ASM.COM
   octet par octet contre xa) et, pour LOGO, `tools/test_logo.sh`.
4. Ajouter à `build.sh` un tableau « taille, blocs, marge avant le bloc
   suivant » pour chaque fichier, et un avertissement sous 256 octets de marge,
   comme ce qui existe déjà pour `$F670` et `$FFFA`.
